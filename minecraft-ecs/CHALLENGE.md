# Minecraft ECS Container Management Challenge

This challenge builds upon the Minecraft ECS lab and will test your knowledge of ECS container management and data backup strategies. You'll learn how to connect to running containers, execute commands inside them, and back up game data to S3.

## Prerequisites

- Complete the Minecraft Server on Amazon ECS Lab first
- Have a running Minecraft ECS service
- AWS CLI configured with appropriate credentials

## Learning Objectives

By completing this challenge, you will learn how to:
- Access ECS container logs
- Execute commands inside a running Fargate container
- Create and manage S3 buckets for backups
- Back up Minecraft world data to S3
- Restore Minecraft world data from S3

## Challenge 1: Accessing Container Logs

Before connecting to your container, it's useful to check the logs to ensure everything is running properly.

**Task**: Retrieve and examine the logs from your running Minecraft container.

<details>
<summary>Hint</summary>
You can use the AWS CLI to retrieve logs from CloudWatch Logs where your container logs are being sent. You'll need your cluster name and task information.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Get your task ID
TASK_ID=$(aws ecs list-tasks \
    --cluster minecraft-cluster \
    --service-name minecraft-service \
    --query 'taskArns[0]' \
    --output text | awk -F '/' '{print $3}')
echo "Task ID: $TASK_ID"

# Step 2: View the logs from CloudWatch
aws logs get-log-events \
    --log-group-name /ecs/minecraft-server \
    --log-stream-name ecs/minecraft-server/$TASK_ID \
    --limit 25
```

You should see log entries showing the Minecraft server startup process. Look for a line indicating the server is ready, such as "Done! For help, type 'help'".
</details>

## Challenge 2: Executing Commands in the Container

Now that you've verified your server is running correctly, let's connect to the container to run commands.

**Task**: Connect to your running Minecraft container and list the contents of the `/data` directory.

<details>
<summary>Hint</summary>
The AWS CLI provides a way to execute commands in a running ECS Fargate task. You'll need the AWS Session Manager plugin installed for this to work.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Ensure you have the Session Manager plugin installed
# For Linux:
# curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
# sudo yum install -y session-manager-plugin.rpm

# For Windows:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Step 2: Get cluster and task information
CLUSTER="minecraft-cluster"
TASK_ID=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --service-name minecraft-service \
    --query 'taskArns[0]' \
    --output text | awk -F '/' '{print $3}')
echo "Task ID: $TASK_ID"

# Step 3: Execute a command to list directory contents
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'ls -la /data'"
```

You should see the Minecraft server files in the `/data` directory, including a `world` folder if players have connected to the server.
</details>

## Challenge 3: Creating an S3 Bucket for Backups

Before backing up your Minecraft world, you need a place to store the backups.

**Task**: Create an S3 bucket to store Minecraft world backups.

<details>
<summary>Hint</summary>
Use the AWS CLI to create an S3 bucket. Remember that S3 bucket names must be globally unique.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Set a unique bucket name
BUCKET_NAME="minecraft-backups-$(aws sts get-caller-identity --query 'Account' --output text)-$(date +%Y%m%d)"
echo "Bucket name: $BUCKET_NAME"

# Step 2: Create the bucket
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region us-east-1

# Step 3: Enable versioning on the bucket (optional but recommended)
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled
```

The command should return a location URL for your new bucket, which confirms it was created successfully.
</details>

## Challenge 4: Backing Up the Minecraft World to S3

Now you'll create a backup of your Minecraft world and upload it to S3.

**Task**: Create a backup archive of the Minecraft world directory and upload it to your S3 bucket.

<details>
<summary>Hint</summary>
You'll need to execute commands in the container to create a backup archive, then use the AWS CLI to copy the file to S3. The AWS CLI isn't available inside the container by default, so you'll need a two-step process.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Set variables
CLUSTER="minecraft-cluster"
TASK_ID=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --service-name minecraft-service \
    --query 'taskArns[0]' \
    --output text | awk -F '/' '{print $3}')
BUCKET_NAME="minecraft-backups-$(aws sts get-caller-identity --query 'Account' --output text)-$(date +%Y%m%d)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="minecraft-world-backup-$TIMESTAMP.tar.gz"
ENI_ID=$(aws ecs describe-tasks \
    --cluster $CLUSTER \
    --tasks $TASK_ID \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $ENI_ID \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

# Step 2: Stop the Minecraft server to ensure data consistency (optional but recommended)
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rcon-cli stop'"

echo "Waiting for server to stop..."
sleep 30

# Step 3: Create backup archive in the container
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'cd /data && tar -czf /tmp/$BACKUP_FILE world'"

echo "Backup archive created inside container"

# Step 4: Create a directory to store the backup locally
mkdir -p ~/minecraft-backups

# Step 5: Start an SSH agent and copy the backup from the container to your local system
# For ECS Fargate, we need to use the ECS exec feature to copy the file
echo "Copying backup from container to local system..."
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'cat /tmp/$BACKUP_FILE'" > ~/minecraft-backups/$BACKUP_FILE

# Step 6: Upload the backup to S3
aws s3 cp ~/minecraft-backups/$BACKUP_FILE s3://$BUCKET_NAME/backups/$BACKUP_FILE

# Step 7: Restart the Minecraft server (if you stopped it)
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'java -Xms1G -Xmx1G -jar /opt/minecraft/server.jar nogui'"

echo "Backup complete and uploaded to S3: s3://$BUCKET_NAME/backups/$BACKUP_FILE"
echo "Reconnect to your Minecraft server at: $PUBLIC_IP:25565"
```

This solution first stops the server (using RCON) to ensure data consistency, creates a backup archive inside the container, copies it to your local system, and then uploads it to S3. Finally, it restarts the Minecraft server.
</details>

## Challenge 5: Restoring a Minecraft World from S3

Now let's test the restore process to ensure your backups are working correctly.

**Task**: Download a backup from S3 and restore it to your Minecraft server.

<details>
<summary>Hint</summary>
Similar to the backup process, you'll need to download the backup from S3, then restore it inside the container.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Set variables
CLUSTER="minecraft-cluster"
TASK_ID=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --service-name minecraft-service \
    --query 'taskArns[0]' \
    --output text | awk -F '/' '{print $3}')
BUCKET_NAME="minecraft-backups-$(aws sts get-caller-identity --query 'Account' --output text)-$(date +%Y%m%d)"
BACKUP_FILE=$(aws s3 ls s3://$BUCKET_NAME/backups/ --recursive | sort | tail -n 1 | awk '{print $4}')
BACKUP_NAME=$(basename $BACKUP_FILE)
ENI_ID=$(aws ecs describe-tasks \
    --cluster $CLUSTER \
    --tasks $TASK_ID \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $ENI_ID \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

# Step 2: Download the backup file from S3
mkdir -p ~/minecraft-backups
aws s3 cp s3://$BUCKET_NAME/$BACKUP_FILE ~/minecraft-backups/$BACKUP_NAME

# Step 3: Stop the Minecraft server
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rcon-cli stop'"

echo "Waiting for server to stop..."
sleep 30

# Step 4: Create a backup of the current world (just in case)
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'cd /data && tar -czf /tmp/world-before-restore.tar.gz world'"

# Step 5: Remove current world folder
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rm -rf /data/world'"

# Step 6: Upload the backup file to the container
# Create the backup file in chunks to handle file size limits
split -b 4M ~/minecraft-backups/$BACKUP_NAME ~/minecraft-backups/backup-chunk-

for chunk in ~/minecraft-backups/backup-chunk-*; do
    chunk_name=$(basename $chunk)
    cat $chunk | aws ecs execute-command \
        --cluster $CLUSTER \
        --task $TASK_ID \
        --container minecraft-server \
        --interactive \
        --command "/bin/sh -c 'cat > /tmp/$chunk_name'"
done

# Step 7: Combine chunks and extract the backup in the container
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'cat /tmp/backup-chunk-* > /tmp/$BACKUP_NAME && rm /tmp/backup-chunk-* && cd /data && tar -xzf /tmp/$BACKUP_NAME'"

# Step 8: Restart the Minecraft server
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'java -Xms1G -Xmx1G -jar /opt/minecraft/server.jar nogui'"

echo "Restore complete. Reconnect to your Minecraft server at: $PUBLIC_IP:25565"
```

This solution downloads a backup from S3, stops the server, creates a backup of the current world, uploads the backup file to the container, extracts it, and then restarts the server.
</details>

## Challenge 6: Automating Backups

For the final challenge, let's automate the backup process so it runs on a schedule.

**Task**: Create a script that will automatically back up your Minecraft world to S3 on a schedule.

<details>
<summary>Hint</summary>
You can use a combination of AWS Lambda, CloudWatch Events, and the ECS API to create an automated backup solution.
</details>

<details>
<summary>Show Solution</summary>

For this solution, we'll create a shell script that can be run by cron or another scheduler:

```bash
# Create a backup script: minecraft-backup.sh
cat > minecraft-backup.sh << 'EOF'
#!/bin/bash

# Configuration
CLUSTER="minecraft-cluster"
SERVICE_NAME="minecraft-service"
BUCKET_NAME="minecraft-backups-$(aws sts get-caller-identity --query 'Account' --output text)-$(date +%Y%m%d)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="minecraft-world-backup-$TIMESTAMP.tar.gz"
LOCAL_BACKUP_DIR=~/minecraft-backups

# Create local backup directory if it doesn't exist
mkdir -p $LOCAL_BACKUP_DIR

# Get task ID
TASK_ID=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --service-name $SERVICE_NAME \
    --query 'taskArns[0]' \
    --output text | awk -F '/' '{print $3}')
echo "Task ID: $TASK_ID"

# Send server message to warn players
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rcon-cli say Server backup starting in 30 seconds. Expect brief lag.'" \
    > /dev/null 2>&1

# Wait for message to be seen
sleep 30

# Send server message again
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rcon-cli say Backup starting now...'" \
    > /dev/null 2>&1

# Save the world to disk before backing up
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rcon-cli save-all'" \
    > /dev/null 2>&1

# Wait for save to complete
sleep 10

# Create backup archive
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'cd /data && tar -czf /tmp/$BACKUP_FILE world'" \
    > /dev/null 2>&1

echo "Backup archive created inside container"

# Copy the backup from the container
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'cat /tmp/$BACKUP_FILE'" > $LOCAL_BACKUP_DIR/$BACKUP_FILE

# Upload to S3
aws s3 cp $LOCAL_BACKUP_DIR/$BACKUP_FILE s3://$BUCKET_NAME/backups/$BACKUP_FILE

# Clean up old local backups (keep last 5)
cd $LOCAL_BACKUP_DIR && ls -1t | tail -n +6 | xargs -r rm

# Send completion message
aws ecs execute-command \
    --cluster $CLUSTER \
    --task $TASK_ID \
    --container minecraft-server \
    --interactive \
    --command "/bin/sh -c 'rcon-cli say Backup complete!'" \
    > /dev/null 2>&1

echo "Backup completed and uploaded to S3: s3://$BUCKET_NAME/backups/$BACKUP_FILE"
EOF

# Make the script executable
chmod +x minecraft-backup.sh

# Set up a cron job to run the backup daily at 3 AM
(crontab -l 2>/dev/null; echo "0 3 * * * $PWD/minecraft-backup.sh > $PWD/minecraft-backup.log 2>&1") | crontab -

echo "Backup automation setup complete. Backups will run daily at 3 AM."
```

This solution creates a shell script that:
1. Warns players about the impending backup
2. Saves the world to disk
3. Creates a backup archive
4. Copies it to your local system
5. Uploads it to S3
6. Cleans up old local backups
7. Notifies players when the backup is complete

It then sets up a cron job to run the backup daily at 3 AM.
</details>

## Validation

To validate that you've successfully completed this challenge:

1. **For Challenge 1**: You should be able to see CloudWatch Logs entries from your Minecraft server.

2. **For Challenge 2**: You should be able to execute commands inside the container and see the contents of the `/data` directory.

3. **For Challenge 3**: You should be able to list your S3 buckets and see the newly created bucket:
   ```bash
   aws s3 ls
   ```

4. **For Challenge 4**: You should be able to list the backup file in your S3 bucket:
   ```bash
   aws s3 ls s3://your-bucket-name/backups/ --recursive
   ```

5. **For Challenge 5**: After restoring from backup, connect to your Minecraft server and verify that the world has been restored correctly.

6. **For Challenge 6**: Check that your backup script runs correctly when executed manually, and that cron is set up to run it automatically:
   ```bash
   crontab -l | grep minecraft
   ```

## Conclusion

In this challenge, you've learned how to:
- Access and manage running ECS containers
- Execute commands inside containers
- Create backups of container data
- Store and retrieve backups from S3
- Automate routine backup tasks

These skills are valuable not just for Minecraft servers, but for managing any containerized application where data persistence and backup are important. 