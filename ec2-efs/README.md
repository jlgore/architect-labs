# EC2 and EFS Integration Lab Using AWS CLI

## Lab Overview
This lab guides students through creating an EC2 instance and attaching an EFS filesystem using only the AWS CLI. The lab is designed to work in a sandbox environment without requiring IAM role modifications.

## Prerequisites
- An AWS sandbox environment with AWS CLI already configured
- Basic understanding of Linux commands
- Basic understanding of AWS services (EC2, EFS, Security Groups)

## Setup Required Packages

Install jq to help parse AWS CLI responses:

```bash
# For Amazon Linux, RHEL, CentOS
sudo yum install -y jq

# For Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y jq

# Verify installation
jq --version
```

## PART 1: Setting Up the Environment

### Create a resource tracking file

```bash
# Create a directory for the lab
mkdir -p ~/ec2-efs-lab/resources
RESOURCE_FILE=~/ec2-efs-lab/resources/resources.txt
touch $RESOURCE_FILE

# Verify AWS CLI access
aws --version
aws sts get-caller-identity

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"  # Default to us-east-1 if no region set
fi
echo "AWS_REGION=$AWS_REGION" >> $RESOURCE_FILE

# Generate a unique identifier to avoid name conflicts
UNIQUE_ID=$(date +%Y%m%d%H%M%S)
echo "UNIQUE_ID=$UNIQUE_ID" >> $RESOURCE_FILE
```

### Create a VPC with multiple subnets

```bash
# Create a new VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=EFSLabVPC-$UNIQUE_ID}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "Created VPC: $VPC_ID"
echo "VPC_ID=$VPC_ID" >> $RESOURCE_FILE

# Enable DNS hostnames and support for the VPC
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}"

# Create an Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=EFSLabIGW-$UNIQUE_ID}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

echo "Created Internet Gateway: $IGW_ID"
echo "IGW_ID=$IGW_ID" >> $RESOURCE_FILE

# Attach the Internet Gateway to the VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

echo "Attached Internet Gateway to VPC"
```

### Create subnets in different availability zones

```bash
# Get available availability zones in the region
AZS=$(aws ec2 describe-availability-zones \
  --region "$AWS_REGION" \
  --query "AvailabilityZones[?State=='available'].ZoneName" \
  --output text)

# Create an array of AZs
AZ_ARR=($AZS)

echo "Available AZs: ${AZ_ARR[@]}"

# Create public subnet in the first AZ
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone "${AZ_ARR[0]}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=EFSLabPublicSubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

echo "Created Public Subnet: $PUBLIC_SUBNET_ID in AZ: ${AZ_ARR[0]}"
echo "PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID" >> $RESOURCE_FILE
echo "PUBLIC_SUBNET_AZ=${AZ_ARR[0]}" >> $RESOURCE_FILE

# Create private subnet in the second AZ
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone "${AZ_ARR[1]}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=EFSLabPrivateSubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

echo "Created Private Subnet: $PRIVATE_SUBNET_ID in AZ: ${AZ_ARR[1]}"
echo "PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID" >> $RESOURCE_FILE
echo "PRIVATE_SUBNET_AZ=${AZ_ARR[1]}" >> $RESOURCE_FILE

# Enable auto-assign public IP on the public subnet
aws ec2 modify-subnet-attribute \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --map-public-ip-on-launch
```

### Create and configure route tables

```bash
# Create a route table for the public subnet
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=EFSLabPublicRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

echo "Created Public Route Table: $PUBLIC_ROUTE_TABLE_ID"
echo "PUBLIC_ROUTE_TABLE_ID=$PUBLIC_ROUTE_TABLE_ID" >> $RESOURCE_FILE

# Create a route to the Internet Gateway
aws ec2 create-route \
  --route-table-id "$PUBLIC_ROUTE_TABLE_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"

# Associate the public route table with the public subnet
aws ec2 associate-route-table \
  --route-table-id "$PUBLIC_ROUTE_TABLE_ID" \
  --subnet-id "$PUBLIC_SUBNET_ID"

# Create a route table for the private subnet
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=EFSLabPrivateRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

echo "Created Private Route Table: $PRIVATE_ROUTE_TABLE_ID"
echo "PRIVATE_ROUTE_TABLE_ID=$PRIVATE_ROUTE_TABLE_ID" >> $RESOURCE_FILE

# Associate the private route table with the private subnet
aws ec2 associate-route-table \
  --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID"

# Set the main subnet for the lab operations
SUBNET_ID=$PUBLIC_SUBNET_ID
SUBNET_AZ=${AZ_ARR[0]}
echo "Main SUBNET_ID=$SUBNET_ID" >> $RESOURCE_FILE
echo "Main SUBNET_AZ=$SUBNET_AZ" >> $RESOURCE_FILE
```

## PART 2: Creating Security Groups

### Create security group for EC2

```bash
# Generate a unique identifier to avoid name conflicts
UNIQUE_ID=$(date +%Y%m%d%H%M%S)

# Create security group for EC2
EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name "ec2-sg-$UNIQUE_ID" \
  --description "Security group for EC2 instances" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" \
  --output text)

echo "Created EC2 security group: $EC2_SG_ID"
echo "EC2_SG_ID=$EC2_SG_ID" >> $RESOURCE_FILE

# Add SSH inbound rule to EC2 security group
aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "Added SSH ingress rule to EC2 security group"
```

### Create security group for EFS

```bash
# Create security group for EFS
EFS_SG_ID=$(aws ec2 create-security-group \
  --group-name "efs-sg-$UNIQUE_ID" \
  --description "Security group for EFS mount targets" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" \
  --output text)

echo "Created EFS security group: $EFS_SG_ID"
echo "EFS_SG_ID=$EFS_SG_ID" >> $RESOURCE_FILE

# Add NFS inbound rule to EFS security group from EC2 security group
aws ec2 authorize-security-group-ingress \
  --group-id "$EFS_SG_ID" \
  --protocol tcp \
  --port 2049 \
  --source-group "$EC2_SG_ID"

```

## PART 3: Creating an EFS Filesystem

### Create the EFS filesystem

```bash
# Create EFS filesystem without tags
EFS_ID=$(aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --encrypted \
  --query "FileSystemId" \
  --output text)

echo "Created EFS filesystem: $EFS_ID"
echo "EFS_ID=$EFS_ID" >> $RESOURCE_FILE

# Wait for EFS to become available
echo "Waiting for EFS filesystem to become available..."
aws efs wait file-system-available --file-system-id "$EFS_ID"
```

### Create mount targets in multiple subnets

```bash
# Create mount target in the public subnet
PUBLIC_MOUNT_TARGET_ID=$(aws efs create-mount-target \
  --file-system-id "$EFS_ID" \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --security-groups "$EFS_SG_ID" \
  --query "MountTargetId" \
  --output text)

echo "Created public mount target: $PUBLIC_MOUNT_TARGET_ID"
echo "PUBLIC_MOUNT_TARGET_ID=$PUBLIC_MOUNT_TARGET_ID" >> $RESOURCE_FILE

# Create mount target in the private subnet
PRIVATE_MOUNT_TARGET_ID=$(aws efs create-mount-target \
  --file-system-id "$EFS_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID" \
  --security-groups "$EFS_SG_ID" \
  --query "MountTargetId" \
  --output text)

echo "Created private mount target: $PRIVATE_MOUNT_TARGET_ID"
echo "PRIVATE_MOUNT_TARGET_ID=$PRIVATE_MOUNT_TARGET_ID" >> $RESOURCE_FILE

# Set the main mount target for the lab
MOUNT_TARGET_ID=$PUBLIC_MOUNT_TARGET_ID
echo "Main MOUNT_TARGET_ID=$MOUNT_TARGET_ID" >> $RESOURCE_FILE

# Wait for mount targets to become available
echo "Waiting for mount targets to become available..."
sleep 15  # Give them a moment to start creating

# Check mount target status
aws efs describe-mount-targets --file-system-id "$EFS_ID" \
  --query "MountTargets[*].{ID:MountTargetId,State:LifeCycleState,AZ:AvailabilityZoneName,SubnetId:SubnetId}"

# Get the EFS DNS name
EFS_DNS_NAME="$EFS_ID.efs.$AWS_REGION.amazonaws.com"
echo "EFS DNS name: $EFS_DNS_NAME"
echo "EFS_DNS_NAME=$EFS_DNS_NAME" >> $RESOURCE_FILE

# Check EFS status
aws efs describe-file-systems --file-system-id "$EFS_ID" \
  --query "FileSystems[0].{ID:FileSystemId,State:LifeCycleState,SizeInBytes:SizeInBytes.Value}"
```

## PART 4: Launching an EC2 Instance

### Find the latest Amazon Linux 2 AMI and create a key pair

```bash
# Find the latest Amazon Linux 2 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)

echo "Using AMI: $AMI_ID"
echo "AMI_ID=$AMI_ID" >> $RESOURCE_FILE

# Create a key pair
KEY_NAME="ec2-efs-lab-key-$UNIQUE_ID"
KEY_FILE="$HOME/ec2-efs-lab/$KEY_NAME.pem"

aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --query "KeyMaterial" \
  --output text > "$KEY_FILE"

# Set proper permissions
chmod 400 "$KEY_FILE"
echo "Created key pair: $KEY_NAME and saved private key to $KEY_FILE"
echo "KEY_NAME=$KEY_NAME" >> $RESOURCE_FILE
echo "KEY_FILE=$KEY_FILE" >> $RESOURCE_FILE
```

### Create user data file for EC2 instance

```bash
# Create user data file
USER_DATA_FILE="$HOME/ec2-efs-lab/user-data.sh"

cat > "$USER_DATA_FILE" << 'USERDATA'
#!/bin/bash
yum update -y
yum install -y amazon-efs-utils nfs-utils jq
mkdir -p /mnt/efs

# Write instance details to a file for verification
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Instance ID: $EC2_INSTANCE_ID" > /home/ec2-user/instance-info.txt
echo "AZ: $EC2_AZ" >> /home/ec2-user/instance-info.txt
echo "Public IP: $EC2_IP" >> /home/ec2-user/instance-info.txt
echo "Setup completed on: $(date)" >> /home/ec2-user/instance-info.txt

chown ec2-user:ec2-user /home/ec2-user/instance-info.txt
USERDATA

echo "Created user data file at $USER_DATA_FILE"
```

### Launch the EC2 instance

```bash
# Launch EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type t2.micro \
  --key-name "$KEY_NAME" \
  --security-group-ids "$EC2_SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --user-data file://"$USER_DATA_FILE" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EFSLabInstance-$UNIQUE_ID}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Launched EC2 instance: $INSTANCE_ID"
echo "INSTANCE_ID=$INSTANCE_ID" >> $RESOURCE_FILE

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Get instance public IP address
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "EC2 instance public IP: $PUBLIC_IP"
echo "PUBLIC_IP=$PUBLIC_IP" >> $RESOURCE_FILE

# Wait a bit more for SSH to be available
echo "Wait about 30-60 seconds for SSH to be available..."
```

## PART 5: Mounting the EFS on the EC2 Instance

### Create a mount script

```bash
# Create a script that will be used to mount the EFS
MOUNT_SCRIPT="$HOME/ec2-efs-lab/mount-efs.sh"

cat > "$MOUNT_SCRIPT" << MOUNTSCRIPT
#!/bin/bash
# This script should be run on the EC2 instance

# Make sure EFS mount directory exists
sudo mkdir -p /mnt/efs

# Mount the EFS filesystem
sudo mount -t efs ${EFS_ID}:/ /mnt/efs

# Verify the mount
df -h | grep efs

# Create a test file
echo "This is a test file created on \$(date)" | sudo tee /mnt/efs/test-\$(hostname).txt

# List files in EFS
ls -la /mnt/efs/

# Configure automatic mounting on reboot
echo "${EFS_ID}:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Display confirmation
echo "EFS mount configured successfully!"
MOUNTSCRIPT

chmod +x "$MOUNT_SCRIPT"
echo "Created EFS mount script at $MOUNT_SCRIPT"
```

### Connect to the EC2 instance and mount EFS

```bash
# First make sure the instance is accessible
# Wait about 60 seconds before the first connection attempt
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "echo 'Connection successful!'"

# Upload and execute the mount script
scp -o StrictHostKeyChecking=no -i "$KEY_FILE" "$MOUNT_SCRIPT" ec2-user@"$PUBLIC_IP":~/
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "chmod +x ~/mount-efs.sh && ~/mount-efs.sh"
```

## PART 6: Testing EFS Persistence

### Test persistence by rebooting the instance

```bash
# Create a timestamp file in EFS before reboot
ssh -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "echo 'Pre-reboot timestamp: $(date)' | sudo tee /mnt/efs/pre-reboot.txt"

# Reboot the instance
aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"

# Wait for instance to be available again (about 1-2 minutes)
echo "Waiting for instance to reboot (60-120 seconds)..."
sleep 60

# Try to reconnect (might need multiple attempts)
echo "Attempting to reconnect..."
# Wait a bit more if first attempt fails
ssh -o ConnectTimeout=5 -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "echo 'Connection successful!'"

# Create post-reboot file
ssh -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "echo 'Post-reboot timestamp: $(date)' | sudo tee /mnt/efs/post-reboot.txt"

# Verify EFS is mounted and files exist
ssh -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "df -h | grep efs && ls -la /mnt/efs/ && cat /mnt/efs/pre-reboot.txt && cat /mnt/efs/post-reboot.txt"
```

## PART 7: Clean Up Resources

### Unmount EFS and terminate EC2

```bash
# Unmount EFS
ssh -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" "sudo umount /mnt/efs"

# Terminate the EC2 instance
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"

# Wait for the instance to terminate
echo "Waiting for instance to terminate..."
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
```

### Delete EFS resources

```bash
# Delete mount targets
echo "Deleting EFS mount targets..."
aws efs describe-mount-targets \
  --file-system-id "$EFS_ID" \
  --query "MountTargets[*].MountTargetId" \
  --output text | \
while read -r MT_ID; do
  if [ -n "$MT_ID" ] && [ "$MT_ID" != "None" ]; then
    echo "Deleting mount target: $MT_ID"
    aws efs delete-mount-target --mount-target-id "$MT_ID"
  fi
done

# Wait for mount targets to be deleted (this may take a few minutes)
echo "Waiting for mount targets to be deleted..."
sleep 30

# Check if any mount targets still exist
MT_COUNT=$(aws efs describe-mount-targets \
  --file-system-id "$EFS_ID" \
  --query "length(MountTargets)" \
  --output text)

# If mount targets still exist, wait longer
if [ "$MT_COUNT" -gt 0 ]; then
  echo "Mount targets still exist. Waiting another 60 seconds..."
  sleep 60
fi

# Delete the filesystem
echo "Deleting EFS filesystem: $EFS_ID"
aws efs delete-file-system --file-system-id "$EFS_ID"
```

### Delete security groups and key pair

```bash
# Delete security groups
# Note: Wait for EC2 instance to be fully terminated first
aws ec2 delete-security-group --group-id "$EFS_SG_ID"  # EFS security group
aws ec2 delete-security-group --group-id "$EC2_SG_ID"  # EC2 security group

# Delete the key pair
aws ec2 delete-key-pair --key-name "$KEY_NAME"
rm "$KEY_FILE"
```

### Delete VPC resources

```bash
# Disassociate route tables from subnets
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[].RouteTableId" \
  --output text | \
while read -r RT_ID; do
  aws ec2 describe-route-tables \
    --route-table-id "$RT_ID" \
    --query "RouteTables[0].Associations[?not SubnetId].AssociationId" \
    --output text | \
  while read -r ASSOC_ID; do
    if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
      aws ec2 disassociate-route-table --association-id "$ASSOC_ID"
    fi
  done
done

# Delete routes in the route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[].RouteTableId" \
  --output text | \
while read -r RT_ID; do
  aws ec2 describe-route-tables \
    --route-table-id "$RT_ID" \
    --query "RouteTables[0].Routes[?not GatewayId].DestinationCidrBlock" \
    --output text | \
  while read -r CIDR; do
    if [ -n "$CIDR" ] && [ "$CIDR" != "None" ]; then
      aws ec2 delete-route --route-table-id "$RT_ID" --destination-cidr-block "$CIDR"
    fi
  done
done

# Delete custom route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" \
  --output text | \
while read -r RT_ID; do
  if [ -n "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
    aws ec2 delete-route-table --route-table-id "$RT_ID"
  fi
done

# Detach the Internet Gateway
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

# Delete the Internet Gateway
aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID"

# Delete subnets
aws ec2 delete-subnet --subnet-id "$PUBLIC_SUBNET_ID"
aws ec2 delete-subnet --subnet-id "$PRIVATE_SUBNET_ID"

# Delete the VPC
aws ec2 delete-vpc --vpc-id "$VPC_ID"

echo "All VPC resources have been deleted"
```

## Lab Questions for Students

1. What role does the security group play in connecting EC2 to EFS?
2. Why is port 2049 specifically needed for EFS?
3. What happens to the data on EFS when the EC2 instance is rebooted?
4. What is the advantage of having mount targets in multiple availability zones?
5. How does EFS differ from EBS in terms of use cases and functionality?
6. What would happen if you terminated the EC2 instance without unmounting the EFS filesystem?
7. How could you secure the EFS data to only allow specific EC2 instances to access it?
8. What performance mode did we use for EFS and what are the alternatives?
9. Why might you want EC2 instances in a private subnet to access an EFS filesystem?
10. What are the benefits of using a custom VPC with public and private subnets instead of the default VPC?

## Extensions and Challenges for Advanced Students

1. Set up automatic backups for the EFS using AWS Backup via CLI
2. Launch EC2 instances in both subnets and verify they can all access the same EFS data
3. Implement a NAT Gateway to allow the private subnet instance to access the internet
4. Set up access points for the EFS filesystem with different IAM permissions
5. Configure lifecycle management policies for the EFS (e.g., transition to Infrequent Access)
6. Create a simple web server on the EC2 instance that serves files from the EFS
7. Implement file-level permissions within the EFS filesystem
8. Set up VPC endpoint for EFS to enhance security by avoiding public internet for EFS access

