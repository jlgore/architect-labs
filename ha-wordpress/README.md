# High Availability WordPress with RDS Lab

This lab demonstrates how to implement a highly available WordPress deployment in AWS using RDS for the database while adhering to sandbox environment constraints.

## Prerequisites

- AWS account with sandbox access
- AWS CLI configured with appropriate credentials
- Basic understanding of AWS services

## Lab Overview

In this lab, you will:
1. Create a VPC with public and private subnets
2. Set up an Application Load Balancer
3. Create an RDS MySQL database for WordPress
4. Configure a Launch Template for WordPress instances 
5. Create an Auto Scaling Group
6. Configure scaling policies
7. Test high availability and scaling

## Step 1: Create VPC and Networking Components

This step creates the networking foundation for our high availability setup. We'll create:
- A VPC with public and private subnets in two availability zones
- An Internet Gateway for public internet access
- A NAT Gateway for private subnet internet access
- Route tables to control traffic flow

```bash
# Set variables for our networking components
VPC_NAME="wp-lab-vpc"
VPC_CIDR="10.0.0.0/16"  # This defines the IP range for our VPC
PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"  # First public subnet in AZ1
PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"  # Second public subnet in AZ2
PRIVATE_SUBNET_1_CIDR="10.0.3.0/24"  # First private subnet in AZ1
PRIVATE_SUBNET_2_CIDR="10.0.4.0/24"  # Second private subnet in AZ2
DB_SUBNET_1_CIDR="10.0.5.0/24"  # First database subnet in AZ1
DB_SUBNET_2_CIDR="10.0.6.0/24"  # Second database subnet in AZ2
REGION="us-east-1"
AZ1="${REGION}a"  # First availability zone
AZ2="${REGION}b"  # Second availability zone

# Create VPC - This is our isolated network environment
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query 'Vpc.VpcId' \
    --output text)
echo "VPC created with ID: $VPC_ID"

# Enable DNS hostnames - Required for public DNS resolution
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Create Internet Gateway - This allows our VPC to connect to the internet
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=wp-lab-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
echo "Internet Gateway created with ID: $IGW_ID"

# Attach IGW to VPC - This connects our VPC to the internet
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

# Create public subnets - These will host our load balancer
PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_1_CIDR \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=wp-lab-public-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Public Subnet 1 created with ID: $PUBLIC_SUBNET_1_ID"

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=wp-lab-public-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Public Subnet 2 created with ID: $PUBLIC_SUBNET_2_ID"

# Create private subnets - These will host our WordPress instances
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_1_CIDR \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=wp-lab-private-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Private Subnet 1 created with ID: $PRIVATE_SUBNET_1_ID"

PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=wp-lab-private-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Private Subnet 2 created with ID: $PRIVATE_SUBNET_2_ID"

# Create database subnets - These will host our RDS database
DB_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $DB_SUBNET_1_CIDR \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=wp-lab-db-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "DB Subnet 1 created with ID: $DB_SUBNET_1_ID"

DB_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $DB_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=wp-lab-db-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "DB Subnet 2 created with ID: $DB_SUBNET_2_ID"

# Create NAT Gateway - This allows private subnets to access the internet
EIP_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --query 'AllocationId' \
    --output text)
echo "Elastic IP created with ID: $EIP_ID"

NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1_ID \
    --allocation-id $EIP_ID \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=wp-lab-nat}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)
echo "NAT Gateway created with ID: $NAT_GW_ID"

# Wait for NAT Gateway to be available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

# Create route tables
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=wp-lab-public-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Public Route Table created with ID: $PUBLIC_RT_ID"

PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=wp-lab-private-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Private Route Table created with ID: $PRIVATE_RT_ID"

DB_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=wp-lab-db-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "DB Route Table created with ID: $DB_RT_ID"

# Add routes to route tables
aws ec2 create-route \
    --route-table-id $PUBLIC_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

aws ec2 create-route \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID

# Associate route tables with subnets
aws ec2 associate-route-table \
    --route-table-id $PUBLIC_RT_ID \
    --subnet-id $PUBLIC_SUBNET_1_ID

aws ec2 associate-route-table \
    --route-table-id $PUBLIC_RT_ID \
    --subnet-id $PUBLIC_SUBNET_2_ID

aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RT_ID \
    --subnet-id $PRIVATE_SUBNET_1_ID

aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RT_ID \
    --subnet-id $PRIVATE_SUBNET_2_ID

aws ec2 associate-route-table \
    --route-table-id $DB_RT_ID \
    --subnet-id $DB_SUBNET_1_ID

aws ec2 associate-route-table \
    --route-table-id $DB_RT_ID \
    --subnet-id $DB_SUBNET_2_ID
```

## Step 2: Create Security Groups

Security groups act as virtual firewalls. We'll create three:
- One for the Application Load Balancer
- One for the WordPress EC2 instances
- One for the RDS database

```bash
# Create ALB security group
ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name wp-lab-alb-sg \
    --description "Security group for WordPress ALB" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "ALB Security Group created with ID: $ALB_SG_ID"

# Create WordPress security group
WP_SG_ID=$(aws ec2 create-security-group \
    --group-name wp-lab-wp-sg \
    --description "Security group for WordPress instances" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "WordPress Security Group created with ID: $WP_SG_ID"

# Create RDS security group
RDS_SG_ID=$(aws ec2 create-security-group \
    --group-name wp-lab-rds-sg \
    --description "Security group for RDS database" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "RDS Security Group created with ID: $RDS_SG_ID"

# Add inbound rules to ALB security group
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Add inbound rules to WordPress security group
aws ec2 authorize-security-group-ingress \
    --group-id $WP_SG_ID \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG_ID

# Add inbound rules to RDS security group
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 3306 \
    --source-group $WP_SG_ID
```

## Step 3: Create RDS Subnet Group and Database

This step creates an RDS MySQL database for WordPress:
- Create a DB subnet group spanning multiple AZs
- Set up a MySQL database
- Configure security and performance settings

```bash
# Create DB subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name wp-lab-db-subnet-group \
    --db-subnet-group-description "Subnet group for WordPress RDS" \
    --subnet-ids $DB_SUBNET_1_ID $DB_SUBNET_2_ID \
    --tags Key=Name,Value=wp-lab-db-subnet-group

# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier wp-lab-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username wpuser \
    --master-user-password wppassword \
    --allocated-storage 20 \
    --db-subnet-group-name wp-lab-db-subnet-group \
    --vpc-security-group-ids $RDS_SG_ID \
    --db-name wordpress \
    --tags Key=Name,Value=wp-lab-db \
    --backup-retention-period 7 \
    --multi-az \
    --storage-type gp2

# Wait for database to be available
aws rds wait db-instance-available \
    --db-instance-identifier wp-lab-db

# Get the RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier wp-lab-db \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"
```

## Step 4: Create Application Load Balancer

The Application Load Balancer (ALB) distributes traffic across our WordPress instances:
- Create the ALB
- Set up a target group
- Configure a listener for HTTP traffic

```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name wp-lab-alb \
    --subnets $PUBLIC_SUBNET_1_ID $PUBLIC_SUBNET_2_ID \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)
echo "ALB created with ARN: $ALB_ARN"

# Create target group
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name wp-lab-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-path /wp-admin/install.php \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
echo "Target Group created with ARN: $TARGET_GROUP_ARN"

# Create listener
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
    --query 'Listeners[0].ListenerArn' \
    --output text)
echo "Listener created with ARN: $LISTENER_ARN"
```

## Step 5: Create Launch Template

The launch template defines how our WordPress EC2 instances will be configured:
- Use Amazon Linux 2023
- Install and configure WordPress
- Connect to the RDS database

```bash
# Get the latest Amazon Linux 2023 AMI ID
AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameter.Value' \
    --output text)
echo "Using AMI ID: $AMI_ID"

# Create launch template
LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name wp-lab-lt \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"t3.micro\",
        \"KeyName\": \"vockey\",
        \"SecurityGroupIds\": [\"$WP_SG_ID\"],
        \"UserData\": \"$(base64 -w0 << EOF
#!/bin/bash
# Update system
dnf update -y

# Install required packages
dnf install -y httpd mariadb105 wget php-fpm php-mysqli php-json php php-devel

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
chown -R apache:apache /var/www/html

# Configure WordPress
cat > /var/www/html/wp-config.php << 'WPCONFIG'
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', 'wppassword');
define('DB_HOST', '$RDS_ENDPOINT');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$(wget -q -O - https://api.wordpress.org/secret-key/1.1/salt/)

\$table_prefix = 'wp_';
define('WP_DEBUG', false);

define('WP_HOME', 'http://' . \$_SERVER['HTTP_HOST']);
define('WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST']);

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
WPCONFIG

# Set permissions
chown apache:apache /var/www/html/wp-config.php
chmod 640 /var/www/html/wp-config.php

# Configure shared EFS storage (optional - for a more complete solution)
# Install EFS utilities
# dnf install -y amazon-efs-utils
# mount -t efs [EFS-ID]:/  /var/www/html/wp-content

# Restart Apache
systemctl restart httpd
EOF
)\"
    }" \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)
echo "Launch Template created with ID: $LAUNCH_TEMPLATE_ID"
```

## Step 6: Create Auto Scaling Group

The Auto Scaling Group manages our WordPress instances:
- Create the group with our launch template
- Configure scaling based on CPU utilization
- Distribute instances across availability zones

```bash
# Create Auto Scaling Group
ASG_NAME="wp-lab-asg"
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --launch-template LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version=\$Latest \
    --vpc-zone-identifier "$PRIVATE_SUBNET_1_ID,$PRIVATE_SUBNET_2_ID" \
    --target-group-arns $TARGET_GROUP_ARN \
    --min-size 2 \
    --max-size 4 \
    --desired-capacity 2 \
    --health-check-type ELB \
    --health-check-grace-period 300

# Create CPU-based scaling policy
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name $ASG_NAME \
    --policy-name wp-cpu-scaling-policy \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration "{
        \"PredefinedMetricSpecification\": {
            \"PredefinedMetricType\": \"ASGAverageCPUUtilization\"
        },
        \"TargetValue\": 70.0,
        \"DisableScaleIn\": false
    }"
```

## Step 7: Test High Availability and Scaling

This step demonstrates the high availability and scaling features:
- Test WordPress accessibility
- Generate load to trigger scaling
- Monitor the scaling process

```bash
# Get the ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
echo "ALB DNS: $ALB_DNS"

# Test WordPress setup
echo "WordPress is now accessible at: http://$ALB_DNS/"
echo "Complete the WordPress setup by visiting: http://$ALB_DNS/wp-admin/install.php"

# Create a load testing script
cat > load_test.sh << 'EOF'
#!/bin/bash
while true; do
    curl -s "http://$ALB_DNS/" > /dev/null &
    sleep 0.1
done
EOF
chmod +x load_test.sh

# Start multiple load testing processes
for i in {1..5}; do
    ./load_test.sh &
    echo "Started load test process $i"
done

# Monitor the Auto Scaling Group
watch -n 5 "aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --query 'AutoScalingGroups[0].{DesiredCapacity:DesiredCapacity,MinSize:MinSize,MaxSize:MaxSize,Instances:Instances[*].{InstanceId:InstanceId,LifecycleState:LifecycleState}}'"

# To stop all load testing processes
pkill -f load_test.sh
```

## Step 8: Clean Up Resources

This step removes all resources to avoid ongoing charges:
- Stop any running load tests
- Terminate all instances
- Delete resources in the correct order

```bash
# First, stop any running load tests
pkill -f load_test.sh

# Get all EC2 instances in the Auto Scaling Group
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
    --output text)

# Terminate all EC2 instances
if [ ! -z "$INSTANCE_IDS" ]; then
    echo "Terminating EC2 instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
    
    # Wait for instances to terminate
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
fi

# Delete Auto Scaling Group
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --force-delete

# Delete Launch Template
aws ec2 delete-launch-template \
    --launch-template-id $LAUNCH_TEMPLATE_ID

# Delete ALB Listener
aws elbv2 delete-listener \
    --listener-arn $LISTENER_ARN

# Delete ALB
aws elbv2 delete-load-balancer \
    --load-balancer-arn $ALB_ARN

# Wait for ALB to be deleted
aws elbv2 wait load-balancers-deleted \
    --load-balancer-arns $ALB_ARN

# Delete Target Group
aws elbv2 delete-target-group \
    --target-group-arn $TARGET_GROUP_ARN

# Delete RDS database
aws rds delete-db-instance \
    --db-instance-identifier wp-lab-db \
    --skip-final-snapshot

# Wait for RDS to be deleted
aws rds wait db-instance-deleted \
    --db-instance-identifier wp-lab-db

# Delete RDS subnet group
aws rds delete-db-subnet-group \
    --db-subnet-group-name wp-lab-db-subnet-group

# Delete NAT Gateway
aws ec2 delete-nat-gateway \
    --nat-gateway-id $NAT_GW_ID

# Wait for NAT Gateway to be deleted
aws ec2 wait nat-gateway-deleted \
    --nat-gateway-ids $NAT_GW_ID

# Release Elastic IP
aws ec2 release-address \
    --allocation-id $EIP_ID

# Delete subnets
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2_ID
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2_ID
aws ec2 delete-subnet --subnet-id $DB_SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $DB_SUBNET_2_ID

# Delete route tables
aws ec2 delete-route-table --route-table-id $PUBLIC_RT_ID
aws ec2 delete-route-table --route-table-id $PRIVATE_RT_ID
aws ec2 delete-route-table --route-table-id $DB_RT_ID

# Detach and delete Internet Gateway
aws ec2 detach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID
aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID

# Delete security groups
aws ec2 delete-security-group --group-id $WP_SG_ID
aws ec2 delete-security-group --group-id $ALB_SG_ID
aws ec2 delete-security-group --group-id $RDS_SG_ID

# Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## Notes

- This lab implements high availability for WordPress by:
  - Using RDS Multi-AZ deployment for database redundancy
  - Distributing WordPress instances across multiple Availability Zones
  - Using an Application Load Balancer for traffic distribution
  - Implementing auto scaling for fault tolerance and performance

- For a production environment, consider these enhancements:
  - Add an EFS file system for shared WordPress uploads and plugins
  - Implement HTTPS with an ACM certificate
  - Set up CloudFront for content delivery
  - Create regular RDS snapshots for backup
  - Implement CloudWatch monitoring and alerts

- The WordPress setup in this lab creates a basic installation
  - For persistent storage across instances, you would need to implement Amazon EFS
  - For session persistence, you could use ElastiCache
  - For media uploads, consider using S3 with the appropriate WordPress plugin
