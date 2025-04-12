# High Availability and Auto Scaling Lab

This lab demonstrates how to implement high availability and auto scaling in AWS while adhering to sandbox environment constraints.

## Prerequisites

- AWS account with sandbox access
- AWS CLI configured with appropriate credentials
- Basic understanding of AWS services

## Lab Overview

In this lab, you will:
1. Create a VPC with public and private subnets
2. Set up an Application Load Balancer
3. Create an Auto Scaling Group
4. Configure scaling policies
5. Test high availability and scaling

## Step 1: Create VPC and Networking Components

```bash
# Set variables
VPC_NAME="ha-lab-vpc"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"
PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"
PRIVATE_SUBNET_1_CIDR="10.0.3.0/24"
PRIVATE_SUBNET_2_CIDR="10.0.4.0/24"
REGION="us-east-1"
AZ1="${REGION}a"
AZ2="${REGION}b"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query 'Vpc.VpcId' \
    --output text)
echo "VPC created with ID: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=ha-lab-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
echo "Internet Gateway created with ID: $IGW_ID"

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

# Create public subnets
PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_1_CIDR \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ha-lab-public-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Public Subnet 1 created with ID: $PUBLIC_SUBNET_1_ID"

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ha-lab-public-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Public Subnet 2 created with ID: $PUBLIC_SUBNET_2_ID"

# Create private subnets
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_1_CIDR \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ha-lab-private-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Private Subnet 1 created with ID: $PRIVATE_SUBNET_1_ID"

PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ha-lab-private-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Private Subnet 2 created with ID: $PRIVATE_SUBNET_2_ID"

# Create NAT Gateway in public subnet 1
EIP_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --query 'AllocationId' \
    --output text)
echo "Elastic IP created with ID: $EIP_ID"

NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1_ID \
    --allocation-id $EIP_ID \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=ha-lab-nat}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)
echo "NAT Gateway created with ID: $NAT_GW_ID"

# Wait for NAT Gateway to be available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

# Create route tables
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=ha-lab-public-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Public Route Table created with ID: $PUBLIC_RT_ID"

PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=ha-lab-private-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Private Route Table created with ID: $PRIVATE_RT_ID"

# Add routes
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
```

## Step 2: Create Security Groups

```bash
# Create ALB security group
ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name ha-lab-alb-sg \
    --description "Security group for ALB" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "ALB Security Group created with ID: $ALB_SG_ID"

# Create EC2 security group
EC2_SG_ID=$(aws ec2 create-security-group \
    --group-name ha-lab-ec2-sg \
    --description "Security group for EC2 instances" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "EC2 Security Group created with ID: $EC2_SG_ID"

# Add inbound rules to ALB security group
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Add inbound rules to EC2 security group
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG_ID
```

## Step 3: Create Application Load Balancer

```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ha-lab-alb \
    --subnets $PUBLIC_SUBNET_1_ID $PUBLIC_SUBNET_2_ID \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)
echo "ALB created with ARN: $ALB_ARN"

# Create target group
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name ha-lab-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-path / \
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

## Step 4: Create Launch Template

```bash
# Get the latest Amazon Linux 2023 AMI ID
AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameter.Value' \
    --output text)
echo "Using AMI ID: $AMI_ID"

# Create launch template
LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name ha-lab-lt \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"t3.micro\",
        \"KeyName\": \"vockey\",
        \"SecurityGroupIds\": [\"$EC2_SG_ID\"],
        \"UserData\": \"$(base64 -w0 << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<html><body><h1>Hello from $(hostname -f)</h1></body></html>" > /var/www/html/index.html
EOF
)\"
    }" \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)
echo "Launch Template created with ID: $LAUNCH_TEMPLATE_ID"
```

## Step 5: Create Auto Scaling Group

```bash
# Create Auto Scaling Group
ASG_NAME="ha-lab-asg"
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
    --policy-name cpu-scaling-policy \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration "{
        \"PredefinedMetricSpecification\": {
            \"PredefinedMetricType\": \"ASGAverageCPUUtilization\"
        },
        \"TargetValue\": 70.0,
        \"DisableScaleIn\": false
    }"
```

## Step 6: Test High Availability and Scaling

1. Get the ALB DNS name:
```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
echo "ALB DNS: $ALB_DNS"
```

2. Test the application by visiting the ALB DNS name in a web browser. You should see responses from different instances.

3. Generate Load Using Multiple Methods:

```bash
# Method 1: Install and use Apache Benchmark
sudo dnf install -y httpd-tools
ab -n 1000 -c 10 http://$ALB_DNS/

# Method 2: Create a load testing script
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

4. Monitor Scaling Events:
```bash
# Watch CloudWatch metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
    --start-time $(date -v-5M -u +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average

# View scaling activities
aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name $ASG_NAME
```

## Step 7: Clean Up Resources

```bash
# First, stop any running load tests
pkill -f load_test.sh

# Delete Auto Scaling Group
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --force-delete

# Delete Launch Template
aws ec2 delete-launch-template \
    --launch-template-id $LAUNCH_TEMPLATE_ID

# Delete ALB Listener first
aws elbv2 delete-listener \
    --listener-arn $LISTENER_ARN

# Delete ALB
aws elbv2 delete-load-balancer \
    --load-balancer-arn $ALB_ARN

# Wait for ALB to be deleted
aws elbv2 wait load-balancers-deleted \
    --load-balancer-arns $ALB_ARN

# Now delete Target Group
aws elbv2 delete-target-group \
    --target-group-arn $TARGET_GROUP_ARN

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
aws ec2 delete-subnet \
    --subnet-id $PUBLIC_SUBNET_1_ID
aws ec2 delete-subnet \
    --subnet-id $PUBLIC_SUBNET_2_ID
aws ec2 delete-subnet \
    --subnet-id $PRIVATE_SUBNET_1_ID
aws ec2 delete-subnet \
    --subnet-id $PRIVATE_SUBNET_2_ID

# Delete route tables
aws ec2 delete-route-table \
    --route-table-id $PUBLIC_RT_ID
aws ec2 delete-route-table \
    --route-table-id $PRIVATE_RT_ID

# Detach and delete Internet Gateway
aws ec2 detach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID
aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID

# Delete VPC
aws ec2 delete-vpc \
    --vpc-id $VPC_ID
```

## Notes

- This lab implements high availability by:
  - Distributing instances across multiple Availability Zones
  - Using an Application Load Balancer for traffic distribution
  - Implementing auto scaling for fault tolerance
  - Using private subnets for instances and public subnets for the ALB

- The scaling policies are configured to:
  - Maintain a minimum of 2 instances
  - Scale up to 4 instances when needed
  - Scale based on CPU utilization
  - Use target tracking for smooth scaling

- All resources are created within the sandbox constraints:
  - Using t3.micro instances
  - Staying within the 9-instance limit
  - Using only supported services and configurations