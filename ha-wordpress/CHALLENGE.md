# High Availability WordPress Challenge Lab

This challenge builds upon the High Availability WordPress with RDS lab and will test your understanding of high availability, load balancing, fault tolerance, and disaster recovery concepts with WordPress.

## Prerequisites

- Complete the High Availability WordPress with RDS Lab first
- Have a running WordPress deployment with:
  - Application Load Balancer
  - Auto Scaling Group with WordPress instances
  - RDS MySQL database
  - AWS CLI configured with appropriate credentials

## Learning Objectives

By completing this challenge, you will learn how to:
- Verify load balancer health and functionality
- Test failover scenarios
- Configure and verify auto scaling policies
- Implement shared storage for WordPress
- Create backup and restore strategies
- Monitor your high availability deployment

## Challenge 1: Verifying Load Balancer Distribution

In a high availability setup, your load balancer should distribute traffic across multiple WordPress instances. Let's verify this is working correctly.

**Task**: Verify that your Application Load Balancer is distributing traffic to multiple WordPress instances.

<details>
<summary>Hint</summary>
You can examine the ALB's target group, check instance health, and confirm traffic distribution using both the AWS CLI and the WordPress application itself.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Get your ALB and target group information
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names wp-lab-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

TG_ARN=$(aws elbv2 describe-target-groups \
    --load-balancer-arn $ALB_ARN \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Step 2: Check registered targets and their health
aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN

# Step 3: Get the DNS name of your ALB
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "Your WordPress site is accessible at http://$ALB_DNS"

# Step 4: Verify traffic distribution using a test plugin
# Access your WordPress admin panel at http://$ALB_DNS/wp-admin
# Install a plugin called "Server IP & Memory Usage Display"
# This will show which server is handling each request
# Refresh your site multiple times to verify requests go to different instances
```

You should see requests being handled by different EC2 instances as you refresh, proving that load balancing is working correctly.
</details>

## Challenge 2: Testing Failover Scenarios

A key aspect of high availability is ensuring service continues even when components fail.

**Task**: Simulate an instance failure and verify that your WordPress site remains available.

<details>
<summary>Hint</summary>
You can manually terminate one of the WordPress instances to simulate a failure, then verify that:
1. The site remains available through the load balancer
2. The auto scaling group launches a replacement instance
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Get a list of EC2 instances in your Auto Scaling Group
ASG_NAME="wp-lab-asg"
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
    --output text)

echo "Current instances: $INSTANCE_IDS"

# Step 2: Choose one instance to terminate (simulate failure)
INSTANCE_TO_TERMINATE=$(echo $INSTANCE_IDS | awk '{print $1}')
echo "Terminating instance: $INSTANCE_TO_TERMINATE"

# Step 3: Terminate the selected instance
aws ec2 terminate-instances \
    --instance-ids $INSTANCE_TO_TERMINATE

echo "Instance termination initiated. Waiting for replacement..."

# Step 4: Monitor the Auto Scaling Group activity
# Watch as the ASG detects the terminated instance and launches a replacement
watch -n 5 "aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --query 'AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId,LifecycleState:LifecycleState,HealthStatus:HealthStatus}' \
    --output table"

# Step 5: Verify WordPress site remains available during the failover
# In another terminal or browser, access your site: http://$ALB_DNS
```

Your WordPress site should remain available throughout the process, with only a brief period where some requests might fail while the unhealthy instance is being removed from the ALB target group. After a few minutes, a new instance should be launched by the Auto Scaling Group.
</details>

## Challenge 3: Configuring EFS for Shared Storage

For true high availability, WordPress instances should share file storage for uploads, plugins, and themes. Let's implement Amazon EFS.

**Task**: Configure Amazon EFS as shared storage for WordPress uploads.

<details>
<summary>Hint</summary>
You'll need to:
1. Create an EFS file system
2. Mount the EFS in your WordPress instances
3. Configure WordPress to use the shared storage for uploads
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Get VPC and subnet information
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=wp-lab-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text)

PRIVATE_SUBNET_1_ID=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=wp-lab-private-1" \
    --query 'Subnets[0].SubnetId' \
    --output text)

PRIVATE_SUBNET_2_ID=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=wp-lab-private-2" \
    --query 'Subnets[0].SubnetId' \
    --output text)

# Step 2: Create a security group for EFS
EFS_SG_ID=$(aws ec2 create-security-group \
    --group-name wp-lab-efs-sg \
    --description "Security group for WordPress EFS" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

# Step 3: Allow NFS traffic from the WordPress instances' security group
WP_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=wp-lab-wp-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $EFS_SG_ID \
    --protocol tcp \
    --port 2049 \
    --source-group $WP_SG_ID

# Step 4: Create the EFS file system
EFS_ID=$(aws efs create-file-system \
    --performance-mode generalPurpose \
    --throughput-mode bursting \
    --encrypted \
    --tags Key=Name,Value=wp-lab-efs \
    --query 'FileSystemId' \
    --output text)

echo "EFS File System created with ID: $EFS_ID"

# Step 5: Create mount targets in private subnets
aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $PRIVATE_SUBNET_1_ID \
    --security-groups $EFS_SG_ID

aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $PRIVATE_SUBNET_2_ID \
    --security-groups $EFS_SG_ID

echo "EFS mount targets created. Waiting for them to become available..."
sleep 30

# Step 6: Update the Launch Template UserData to mount EFS
# Get the current Launch Template ID and latest version
LAUNCH_TEMPLATE_ID=$(aws ec2 describe-launch-templates \
    --filters "Name=launch-template-name,Values=wp-lab-lt" \
    --query 'LaunchTemplates[0].LaunchTemplateId' \
    --output text)

LATEST_VERSION=$(aws ec2 describe-launch-templates \
    --launch-template-ids $LAUNCH_TEMPLATE_ID \
    --query 'LaunchTemplates[0].LatestVersionNumber' \
    --output text)

# Get the current launch template data
aws ec2 get-launch-template-data \
    --launch-template-id $LAUNCH_TEMPLATE_ID \
    --version-number $LATEST_VERSION > launch-template-data.json

# Edit the launch template to include EFS mounting
# Note: In a real scenario, you would update the full UserData script
# Here's a sample UserData addition for mounting EFS:

# Create a new version of the launch template with updated UserData
cat > efs-userdata.txt << EOF
#!/bin/bash
# Update system
dnf update -y

# Install required packages
dnf install -y httpd mariadb105 wget php-fpm php-mysqli php-json php php-devel amazon-efs-utils

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Install WordPress
mkdir -p /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz -C /var/www/html/
mv /var/www/html/wordpress/* /var/www/html/
rm -rf /var/www/html/wordpress
rm latest.tar.gz

# Configure WordPress
# ... existing wp-config.php setup ...

# Mount EFS for uploads directory
mkdir -p /var/www/html/wp-content/uploads
echo "$EFS_ID:/ /var/www/html/wp-content/uploads efs _netdev,tls,iam 0 0" >> /etc/fstab
mount -a

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache
systemctl restart httpd
EOF

# Encode the UserData script as base64
USERDATA=$(base64 -w0 efs-userdata.txt)

# Create a new version of the launch template
aws ec2 create-launch-template-version \
    --launch-template-id $LAUNCH_TEMPLATE_ID \
    --version-description "Added EFS for shared uploads" \
    --source-version $LATEST_VERSION \
    --launch-template-data "{\"UserData\":\"$USERDATA\"}"

# Update the Auto Scaling Group to use the latest template version
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --launch-template LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version=\$Latest

# Step 7: Refresh instances to use the new configuration
aws autoscaling start-instance-refresh \
    --auto-scaling-group-name $ASG_NAME \
    --preferences MinHealthyPercentage=50

echo "Instance refresh started. New instances will mount the EFS volume."
echo "Once complete, upload a file through WordPress and verify it's accessible from all instances."
```

After the instance refresh completes:
1. Access your WordPress admin panel
2. Upload a media file
3. The file should now be stored on EFS and accessible from all WordPress instances

You can verify this by terminating instances and confirming the uploaded files remain accessible.
</details>

## Challenge 4: Implementing Database Failover

Let's test database failover to ensure WordPress can handle database unavailability.

**Task**: Simulate a database failover and verify WordPress continues to function.

<details>
<summary>Hint</summary>
RDS Multi-AZ deployments handle failover automatically. You can force a failover to test this functionality.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Get your RDS instance identifier
DB_INSTANCE_ID=$(aws rds describe-db-instances \
    --query 'DBInstances[?DBName==`wordpress`].DBInstanceIdentifier' \
    --output text)

echo "Database instance ID: $DB_INSTANCE_ID"

# Step 2: Verify Multi-AZ is enabled
MULTI_AZ=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --query 'DBInstances[0].MultiAZ' \
    --output text)

if [ "$MULTI_AZ" != "true" ]; then
    echo "Multi-AZ is not enabled. Enabling it now..."
    
    # Enable Multi-AZ if not already enabled
    aws rds modify-db-instance \
        --db-instance-identifier $DB_INSTANCE_ID \
        --multi-az \
        --apply-immediately
    
    echo "Waiting for Multi-AZ configuration to complete (this may take several minutes)..."
    aws rds wait db-instance-available \
        --db-instance-identifier $DB_INSTANCE_ID
else
    echo "Multi-AZ is already enabled."
fi

# Step 3: Check the current AZ before failover
CURRENT_AZ=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --query 'DBInstances[0].AvailabilityZone' \
    --output text)

echo "Current primary AZ: $CURRENT_AZ"

# Step 4: Force a failover
echo "Initiating database failover..."
aws rds reboot-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --force-failover

# Step 5: Wait for the failover to complete
echo "Waiting for failover to complete..."
aws rds wait db-instance-available \
    --db-instance-identifier $DB_INSTANCE_ID

# Step 6: Check the new AZ after failover
NEW_AZ=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --query 'DBInstances[0].AvailabilityZone' \
    --output text)

echo "New primary AZ: $NEW_AZ"

# Step 7: Verify WordPress is still functioning
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names wp-lab-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "Verify WordPress is working at http://$ALB_DNS"
echo "Try performing some database operations (creating a post, commenting, etc.)"
```

During the failover process, WordPress might experience a brief period (typically 60-120 seconds) of database unavailability. After the failover completes, the site should return to normal operation, demonstrating the resilience of the Multi-AZ RDS configuration.
</details>

## Challenge 5: Testing Auto Scaling

Let's verify that your Auto Scaling Group scales out under load.

**Task**: Generate load on your WordPress site and verify that the Auto Scaling Group adds instances.

<details>
<summary>Hint</summary>
You can use a load testing tool to generate traffic to your WordPress site, then monitor the Auto Scaling Group to see new instances being added.
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Get your Auto Scaling Group details
ASG_NAME="wp-lab-asg"
ASG_INFO=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --query 'AutoScalingGroups[0].{MinSize:MinSize,MaxSize:MaxSize,DesiredCapacity:DesiredCapacity}')

echo "Current ASG configuration: $ASG_INFO"

# Step 2: Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names wp-lab-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Step 3: Create a simple load testing script
cat > load-test.sh << 'EOF'
#!/bin/bash
URL="http://$1"
CONCURRENT=10
REQUESTS=1000

# Install Apache Bench if not present
if ! command -v ab &> /dev/null; then
    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y apache2-utils
    elif [ -f /etc/redhat-release ]; then
        yum install -y httpd-tools
    else
        echo "Cannot install Apache Bench. Please install manually."
        exit 1
    fi
fi

# Run load test
echo "Starting load test on $URL with $CONCURRENT concurrent users..."
ab -n $REQUESTS -c $CONCURRENT -k "$URL/"
EOF

chmod +x load-test.sh

# Step 4: Run the load test
echo "Running load test against http://$ALB_DNS"
./load-test.sh "$ALB_DNS"

# Step 5: Monitor the Auto Scaling Group in another terminal
echo "In another terminal, run this command to monitor scaling activities:"
echo "watch -n 5 \"aws autoscaling describe-auto-scaling-groups \\"
echo "    --auto-scaling-group-names $ASG_NAME \\"
echo "    --query 'AutoScalingGroups[0].{DesiredCapacity:DesiredCapacity,Instances:Instances[*].{InstanceId:InstanceId,LifecycleState:LifecycleState}}' \\"
echo "    --output table\""

# Step 6: Increase the load if needed
echo "If no scaling occurs, you may need to increase the load:"
echo "./load-test.sh \"$ALB_DNS\" 20 2000  # 20 concurrent users, 2000 requests"

# Step 7: Check CloudWatch metrics to see the CPU utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
    --start-time $(date -u -v-30M "+%Y-%m-%dT%H:%M:%SZ") \
    --end-time $(date -u "+%Y-%m-%dT%H:%M:%SZ") \
    --period 60 \
    --statistics Average \
    --query 'Datapoints[*].{Timestamp:Timestamp,Average:Average}'
```

As the load test runs, monitor the Auto Scaling Group activity. You should see:
1. Increased CPU utilization
2. Scale-out actions being triggered
3. New instances being launched when the CPU utilization exceeds your defined threshold (typically 70%)

After the load test completes, the system should eventually scale back down.
</details>

## Challenge 6: Implementing Disaster Recovery

Now let's create a disaster recovery plan with database backups and WordPress content backup.

**Task**: Create and test a complete backup and restore strategy for your WordPress deployment.

<details>
<summary>Hint</summary>
A complete DR strategy should include:
1. Database backups (RDS snapshots)
2. WordPress file backups (EFS or EC2 content)
3. Configuration backups (launch template, security groups, etc.)
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Create an RDS snapshot
DB_INSTANCE_ID=$(aws rds describe-db-instances \
    --query 'DBInstances[?DBName==`wordpress`].DBInstanceIdentifier' \
    --output text)

SNAPSHOT_ID="wp-manual-backup-$(date +%Y%m%d-%H%M%S)"

echo "Creating RDS snapshot: $SNAPSHOT_ID"
aws rds create-db-snapshot \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-snapshot-identifier $SNAPSHOT_ID

echo "Waiting for snapshot to complete..."
aws rds wait db-snapshot-completed \
    --db-snapshot-identifier $SNAPSHOT_ID

# Step 2: Create an EFS backup (if you implemented Challenge 3)
# Create a backup vault if you don't have one
BACKUP_VAULT_NAME="wordpress-backups"

aws backup create-backup-vault \
    --backup-vault-name $BACKUP_VAULT_NAME

# Get the EFS ID
EFS_ID=$(aws efs describe-file-systems \
    --query 'FileSystems[?Name==`wp-lab-efs`].FileSystemId' \
    --output text)

if [ -n "$EFS_ID" ]; then
    # Create an on-demand backup of the EFS
    BACKUP_JOB_ID=$(aws backup start-backup-job \
        --backup-vault-name $BACKUP_VAULT_NAME \
        --resource-arn arn:aws:elasticfilesystem:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):file-system/$EFS_ID \
        --iam-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/service-role/AWSBackupDefaultServiceRole \
        --lifecycle DeleteAfterDays=30 \
        --query BackupJobId \
        --output text)
    
    echo "EFS backup job started with ID: $BACKUP_JOB_ID"
fi

# Step 3: Create a CloudFormation template for infrastructure
cat > wordpress-backup.yaml << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: 'WordPress High Availability Backup Information'
Resources: {}
Outputs:
  VPC:
    Description: VPC ID
    Value: ${VPC_ID}
  DBInstanceID:
    Description: RDS Instance ID
    Value: ${DB_INSTANCE_ID}
  DBSnapshotID:
    Description: Latest Database Snapshot ID
    Value: ${SNAPSHOT_ID}
  LaunchTemplateID:
    Description: EC2 Launch Template ID
    Value: ${LAUNCH_TEMPLATE_ID}
  EFSID:
    Description: EFS File System ID for WordPress content
    Value: ${EFS_ID:-None}
  EFSBackupJobID:
    Description: EFS Backup Job ID
    Value: ${BACKUP_JOB_ID:-None}
  ASGName:
    Description: Auto Scaling Group Name
    Value: ${ASG_NAME}
  ALBARNs:
    Description: Application Load Balancer ARN
    Value: ${ALB_ARN}
EOF

# Step 4: Save the CloudFormation template to S3
BUCKET_NAME="wordpress-backups-$(aws sts get-caller-identity --query 'Account' --output text)"

# Create the bucket if it doesn't exist
if ! aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $(aws configure get region)
fi

# Upload the backup info
aws s3 cp wordpress-backup.yaml s3://$BUCKET_NAME/wordpress-backup-$(date +%Y%m%d-%H%M%S).yaml

echo "Disaster recovery information saved to S3://$BUCKET_NAME"

# Step 5: Create a disaster recovery script
cat > wordpress-restore.sh << 'EOF'
#!/bin/bash
# WordPress Disaster Recovery Script

# Required inputs
if [ $# -lt 2 ]; then
    echo "Usage: $0 <S3_BUCKET> <BACKUP_TEMPLATE_KEY>"
    exit 1
fi

S3_BUCKET=$1
BACKUP_TEMPLATE_KEY=$2

# Download the backup template
aws s3 cp s3://$S3_BUCKET/$BACKUP_TEMPLATE_KEY wordpress-restore.yaml

# Extract values from the template
VPC_ID=$(grep -A1 "VPC:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
DB_INSTANCE_ID=$(grep -A1 "DBInstanceID:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
DB_SNAPSHOT_ID=$(grep -A1 "DBSnapshotID:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
LAUNCH_TEMPLATE_ID=$(grep -A1 "LaunchTemplateID:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
EFS_ID=$(grep -A1 "EFSID:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
EFS_BACKUP_JOB_ID=$(grep -A1 "EFSBackupJobID:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
ASG_NAME=$(grep -A1 "ASGName:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')
ALB_ARN=$(grep -A1 "ALBARNs:" wordpress-restore.yaml | grep "Value" | awk '{print $2}')

echo "Restore values:"
echo "VPC: $VPC_ID"
echo "DB Instance: $DB_INSTANCE_ID"
echo "DB Snapshot: $DB_SNAPSHOT_ID"
echo "Launch Template: $LAUNCH_TEMPLATE_ID"
echo "EFS: $EFS_ID"
echo "EFS Backup Job: $EFS_BACKUP_JOB_ID"
echo "ASG: $ASG_NAME"
echo "ALB: $ALB_ARN"

# Implement restore logic based on the backed up values
# For a real DR scenario, you would:
# 1. Restore RDS from snapshot
# 2. Restore EFS from backup
# 3. Re-create the WordPress instances with the launch template
# 4. Configure everything to work together again

echo "This script provides the information needed for a disaster recovery."
echo "For a complete restore, you would need to implement the specific restore steps."
EOF

chmod +x wordpress-restore.sh

# Step 6: Upload the restore script to S3
aws s3 cp wordpress-restore.sh s3://$BUCKET_NAME/wordpress-restore.sh

echo "Disaster recovery script saved to S3://$BUCKET_NAME/wordpress-restore.sh"
echo "To restore, run: ./wordpress-restore.sh $BUCKET_NAME wordpress-backup-$(date +%Y%m%d-%H%M%S).yaml"
```

This solution creates:
1. An RDS database snapshot
2. An EFS backup (if EFS is being used)
3. A CloudFormation template with key information about your resources
4. A restore script template that can be used in a disaster recovery scenario

For a full disaster recovery test, you would:
1. Create a new VPC and subnets in another region
2. Restore the RDS database from the snapshot
3. Create a new EFS file system and restore the data
4. Launch WordPress instances with the saved configuration
5. Set up a new load balancer
6. Verify WordPress functionality in the new environment
</details>

## Challenge 7: Monitoring Your High Availability Setup

Let's implement comprehensive monitoring for your WordPress setup.

**Task**: Set up CloudWatch alarms and dashboards to monitor your high availability WordPress deployment.

<details>
<summary>Hint</summary>
You should monitor key aspects of your stack, including:
1. Load balancer metrics
2. EC2 instance health and performance
3. RDS database metrics
4. EFS metrics (if applicable)
</details>

<details>
<summary>Show Solution</summary>

```bash
# Step 1: Create CloudWatch alarms for key metrics

# Load Balancer alarm for high latency
aws cloudwatch put-metric-alarm \
    --alarm-name "WP-HighLatency" \
    --alarm-description "Alarm when latency exceeds 1 second" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers --names wp-lab-alb --query 'LoadBalancers[0].LoadBalancerName' --output text) \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):wordpress-alerts

# RDS CPU Utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "WP-DB-HighCPU" \
    --alarm-description "Alarm when database CPU exceeds 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE_ID \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):wordpress-alerts

# Auto Scaling Group capacity alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "WP-ASG-NearMaxCapacity" \
    --alarm-description "Alarm when ASG is near max capacity" \
    --metric-name GroupInServiceInstances \
    --namespace AWS/AutoScaling \
    --statistic Maximum \
    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
    --period 60 \
    --evaluation-periods 1 \
    --threshold $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].MaxSize-1' --output text) \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):wordpress-alerts

# EFS throughput alarm (if you implemented Challenge 3)
if [ -n "$EFS_ID" ]; then
    aws cloudwatch put-metric-alarm \
        --alarm-name "WP-EFS-HighThroughput" \
        --alarm-description "Alarm when EFS throughput is high" \
        --metric-name TotalIOBytes \
        --namespace AWS/EFS \
        --statistic Average \
        --dimensions Name=FileSystemId,Value=$EFS_ID \
        --period 300 \
        --evaluation-periods 2 \
        --threshold 10000000 \
        --comparison-operator GreaterThanThreshold \
        --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):wordpress-alerts
fi

# Step 2: Create a dashboard for all WordPress components
cat > wordpress-dashboard.json << EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$(aws elbv2 describe-load-balancers --names wp-lab-alb --query 'LoadBalancers[0].LoadBalancerName' --output text)" ],
                    [ ".", "TargetResponseTime", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "Load Balancer Metrics",
                "period": 300
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "$ASG_NAME" ],
                    [ ".", "NetworkIn", ".", "." ],
                    [ ".", "NetworkOut", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "EC2 Instance Metrics",
                "period": 300
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "$DB_INSTANCE_ID" ],
                    [ ".", "DatabaseConnections", ".", "." ],
                    [ ".", "ReadIOPS", ".", "." ],
                    [ ".", "WriteIOPS", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "RDS Database Metrics",
                "period": 300
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "$ASG_NAME" ],
                    [ ".", "GroupTotalInstances", ".", "." ],
                    [ ".", "GroupMaxSize", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "Auto Scaling Group Metrics",
                "period": 300
            }
        }
    ]
}
EOF

# Step 3: Create the CloudWatch dashboard
aws cloudwatch put-dashboard \
    --dashboard-name WordPress-Monitoring \
    --dashboard-body file://wordpress-dashboard.json

echo "WordPress monitoring dashboard created: WordPress-Monitoring"
echo "View it in the CloudWatch console: https://console.aws.amazon.com/cloudwatch/home?region=$(aws configure get region)#dashboards:name=WordPress-Monitoring"
```

This solution creates:
1. CloudWatch alarms for critical metrics:
   - Load balancer latency
   - Database CPU usage
   - Auto Scaling Group capacity
   - EFS throughput (if applicable)
2. A comprehensive CloudWatch dashboard showing:
   - Load balancer metrics
   - EC2 instance metrics
   - RDS database metrics
   - Auto Scaling Group metrics

These monitoring tools help you proactively identify issues and ensure the high availability of your WordPress deployment.
</details>

## Validation

To validate that you've successfully completed this challenge:

1. **For Challenge 1**: Your ALB should show healthy targets in multiple Availability Zones, and requests should be distributed to different instances.

2. **For Challenge 2**: Your WordPress site should remain available when an instance is terminated, and a new instance should be launched automatically.

3. **For Challenge 3**: After implementing EFS, all WordPress instances should have access to the same uploads, themes, and plugins.

4. **For Challenge 4**: Your WordPress site should continue functioning after forcing an RDS failover, with minimal disruption.

5. **For Challenge 5**: Your Auto Scaling Group should launch additional instances when the site is under load.

6. **For Challenge 6**: You should have a complete backup strategy that can be used to restore your WordPress deployment in case of a disaster.

7. **For Challenge 7**: Your CloudWatch dashboard should provide comprehensive visibility into the health and performance of your WordPress deployment.

## Conclusion

In this challenge, you've learned how to:
- Verify and test critical high availability components
- Configure shared storage for WordPress
- Implement and test failover scenarios
- Set up auto scaling
- Create a comprehensive backup and disaster recovery strategy
- Implement monitoring for your high availability deployment

These skills are essential for managing production WordPress deployments that require high reliability, performance, and scalability. 