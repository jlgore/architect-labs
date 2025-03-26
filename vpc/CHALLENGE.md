# AWS VPC Advanced Challenge: Multi-Region VPC Peering

This challenge builds on the basic VPC lab and introduces more complex AWS networking concepts. You'll create a multi-region network architecture with VPC peering to allow communication between resources in different regions.

## Challenge Overview

In this challenge, you will:
1. Create VPCs in two different AWS regions
2. Set up EC2 instances in each VPC
3. Establish VPC peering between the two regions
4. Configure route tables to enable cross-VPC communication
5. Test connectivity between instances in different regions

## Prerequisites

- Completed the basic VPC lab
- AWS account with access to multiple regions
- Basic understanding of AWS networking concepts

## Challenge Steps

### Part 1: Create Two VPCs in Different Regions

First, you'll need to create VPCs in two different AWS regions. Each VPC should have its own CIDR block that doesn't overlap with the other.

Requirements:
- Create a VPC in your primary region (e.g., us-east-1) with CIDR block 10.0.0.0/16
- Create a VPC in your secondary region (e.g., us-west-2) with CIDR block 172.16.0.0/16
- Add appropriate tags to identify your VPCs
- Record the VPC IDs for later use

<details>
<summary>Click to reveal solution for creating VPCs</summary>

```bash
# Set up environment variables for the first region
PRIMARY_REGION="us-east-1"
PRIMARY_VPC_CIDR="10.0.0.0/16"
PRIMARY_SUBNET_CIDR="10.0.1.0/24"
UNIQUE_ID=$(date +%Y%m%d%H%M%S)

# Create the first VPC
PRIMARY_VPC_ID=$(aws ec2 create-vpc \
  --region $PRIMARY_REGION \
  --cidr-block $PRIMARY_VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=PrimaryVPC-$UNIQUE_ID}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "Created Primary VPC: $PRIMARY_VPC_ID in region $PRIMARY_REGION"
```

```bash
# Set up environment variables for the second region
SECONDARY_REGION="us-west-2"
SECONDARY_VPC_CIDR="172.16.0.0/16"
SECONDARY_SUBNET_CIDR="172.16.1.0/24"

# Create the second VPC
SECONDARY_VPC_ID=$(aws ec2 create-vpc \
  --region $SECONDARY_REGION \
  --cidr-block $SECONDARY_VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=SecondaryVPC-$UNIQUE_ID}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "Created Secondary VPC: $SECONDARY_VPC_ID in region $SECONDARY_REGION"
```
</details>

### Part 2: Configure Subnets, Internet Gateway, and Route Tables

Next, you need to configure networking components for both VPCs:
- Create public subnets in each VPC
- Set up Internet Gateways for internet access
- Configure route tables with appropriate routes

For each region, you should:
1. Enable DNS hostnames and support for your VPC
2. Create a public subnet in an availability zone
3. Create and attach an Internet Gateway to your VPC
4. Create a route table with a default route to the Internet Gateway
5. Associate the route table with your subnet
6. Enable auto-assign public IP for the subnet

<details>
<summary>Click to reveal solution for configuring subnets, Internet Gateways, and route tables</summary>

1. For the Primary VPC:

```bash
# Enable DNS support and hostnames
aws ec2 modify-vpc-attribute --region $PRIMARY_REGION --vpc-id $PRIMARY_VPC_ID --enable-dns-hostnames "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region $PRIMARY_REGION --vpc-id $PRIMARY_VPC_ID --enable-dns-support "{\"Value\":true}"

# Create a subnet
PRIMARY_SUBNET_ID=$(aws ec2 create-subnet \
  --region $PRIMARY_REGION \
  --vpc-id $PRIMARY_VPC_ID \
  --cidr-block $PRIMARY_SUBNET_CIDR \
  --availability-zone "${PRIMARY_REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=PrimarySubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

# Create and attach Internet Gateway
PRIMARY_IGW_ID=$(aws ec2 create-internet-gateway \
  --region $PRIMARY_REGION \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=PrimaryIGW-$UNIQUE_ID}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --region $PRIMARY_REGION \
  --internet-gateway-id $PRIMARY_IGW_ID \
  --vpc-id $PRIMARY_VPC_ID

# Create route table and add internet route
PRIMARY_RT_ID=$(aws ec2 create-route-table \
  --region $PRIMARY_REGION \
  --vpc-id $PRIMARY_VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=PrimaryRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-route \
  --region $PRIMARY_REGION \
  --route-table-id $PRIMARY_RT_ID \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id $PRIMARY_IGW_ID

aws ec2 associate-route-table \
  --region $PRIMARY_REGION \
  --subnet-id $PRIMARY_SUBNET_ID \
  --route-table-id $PRIMARY_RT_ID

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
  --region $PRIMARY_REGION \
  --subnet-id $PRIMARY_SUBNET_ID \
  --map-public-ip-on-launch
```

2. For the Secondary VPC:

```bash
# Enable DNS support and hostnames
aws ec2 modify-vpc-attribute --region $SECONDARY_REGION --vpc-id $SECONDARY_VPC_ID --enable-dns-hostnames "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region $SECONDARY_REGION --vpc-id $SECONDARY_VPC_ID --enable-dns-support "{\"Value\":true}"

# Create a subnet
SECONDARY_SUBNET_ID=$(aws ec2 create-subnet \
  --region $SECONDARY_REGION \
  --vpc-id $SECONDARY_VPC_ID \
  --cidr-block $SECONDARY_SUBNET_CIDR \
  --availability-zone "${SECONDARY_REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=SecondarySubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

# Create and attach Internet Gateway
SECONDARY_IGW_ID=$(aws ec2 create-internet-gateway \
  --region $SECONDARY_REGION \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=SecondaryIGW-$UNIQUE_ID}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --region $SECONDARY_REGION \
  --internet-gateway-id $SECONDARY_IGW_ID \
  --vpc-id $SECONDARY_VPC_ID

# Create route table and add internet route
SECONDARY_RT_ID=$(aws ec2 create-route-table \
  --region $SECONDARY_REGION \
  --vpc-id $SECONDARY_VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=SecondaryRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-route \
  --region $SECONDARY_REGION \
  --route-table-id $SECONDARY_RT_ID \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id $SECONDARY_IGW_ID

aws ec2 associate-route-table \
  --region $SECONDARY_REGION \
  --subnet-id $SECONDARY_SUBNET_ID \
  --route-table-id $SECONDARY_RT_ID

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
  --region $SECONDARY_REGION \
  --subnet-id $SECONDARY_SUBNET_ID \
  --map-public-ip-on-launch
```
</details>

### Part 3: Create Security Groups

Now, create security groups in both VPCs to control traffic. You'll need to allow:
- SSH access from the internet (for demonstration purposes)
- ICMP (ping) between VPCs

For each region, create a security group that:
1. Allows SSH (port 22) inbound from anywhere
2. Allows ICMP inbound from the other VPC's CIDR block
3. Has appropriate tags for identification

<details>
<summary>Click to reveal solution for creating security groups</summary>

1. For the Primary VPC:

```bash
# Create security group
PRIMARY_SG_ID=$(aws ec2 create-security-group \
  --region $PRIMARY_REGION \
  --group-name "sg-primary-$UNIQUE_ID" \
  --description "Security group for Primary VPC instances" \
  --vpc-id $PRIMARY_VPC_ID \
  --query "GroupId" \
  --output text)

# Allow SSH from anywhere
aws ec2 authorize-security-group-ingress \
  --region $PRIMARY_REGION \
  --group-id $PRIMARY_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Allow ICMP (ping) from the Secondary VPC CIDR
aws ec2 authorize-security-group-ingress \
  --region $PRIMARY_REGION \
  --group-id $PRIMARY_SG_ID \
  --protocol icmp \
  --port -1 \
  --cidr $SECONDARY_VPC_CIDR
```

2. For the Secondary VPC:

```bash
# Create security group
SECONDARY_SG_ID=$(aws ec2 create-security-group \
  --region $SECONDARY_REGION \
  --group-name "sg-secondary-$UNIQUE_ID" \
  --description "Security group for Secondary VPC instances" \
  --vpc-id $SECONDARY_VPC_ID \
  --query "GroupId" \
  --output text)

# Allow SSH from anywhere
aws ec2 authorize-security-group-ingress \
  --region $SECONDARY_REGION \
  --group-id $SECONDARY_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Allow ICMP (ping) from the Primary VPC CIDR
aws ec2 authorize-security-group-ingress \
  --region $SECONDARY_REGION \
  --group-id $SECONDARY_SG_ID \
  --protocol icmp \
  --port -1 \
  --cidr $PRIMARY_VPC_CIDR
```
</details>

### Part 4: Launch EC2 Instances

Launch EC2 instances in both VPCs. You'll need to:
- Create a key pair for SSH access
- Find the appropriate Amazon Linux 2 AMI for each region
- Launch instances with the correct security groups

Requirements:
1. Create or import a key pair for SSH access
2. Find the latest Amazon Linux 2 AMI in each region
3. Launch t3.micro instances in both regions
4. Assign the security groups you created earlier
5. Tag your instances appropriately

<details>
<summary>Click to reveal solution for launching EC2 instances</summary>

1. Create a key pair (or use an existing one) and launch instances in both regions:

```bash
# Create a key pair for the primary region
aws ec2 create-key-pair \
  --region $PRIMARY_REGION \
  --key-name "vpc-challenge-key-$UNIQUE_ID" \
  --query "KeyMaterial" \
  --output text > vpc-challenge-key.pem

chmod 400 vpc-challenge-key.pem

# Import the same key to the secondary region
aws ec2 import-key-pair \
  --region $SECONDARY_REGION \
  --key-name "vpc-challenge-key-$UNIQUE_ID" \
  --public-key-material fileb://$(aws ec2 describe-key-pairs \
    --region $PRIMARY_REGION \
    --key-name "vpc-challenge-key-$UNIQUE_ID" \
    --query "KeyPairs[0].PublicKey" \
    --output text)
```

2. Launch an instance in the Primary VPC:

```bash
# Get the latest Amazon Linux 2 AMI ID for the primary region
PRIMARY_AMI_ID=$(aws ec2 describe-images \
  --region $PRIMARY_REGION \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)

# Launch the instance
PRIMARY_INSTANCE_ID=$(aws ec2 run-instances \
  --region $PRIMARY_REGION \
  --image-id $PRIMARY_AMI_ID \
  --instance-type t3.micro \
  --key-name "vpc-challenge-key-$UNIQUE_ID" \
  --security-group-ids $PRIMARY_SG_ID \
  --subnet-id $PRIMARY_SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=PrimaryInstance-$UNIQUE_ID}]" \
  --query "Instances[0].InstanceId" \
  --output text)

# Get the public IP address
PRIMARY_INSTANCE_IP=$(aws ec2 describe-instances \
  --region $PRIMARY_REGION \
  --instance-ids $PRIMARY_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Primary Instance launched with IP: $PRIMARY_INSTANCE_IP"
```

3. Launch an instance in the Secondary VPC:

```bash
# Get the latest Amazon Linux 2 AMI ID for the secondary region
SECONDARY_AMI_ID=$(aws ec2 describe-images \
  --region $SECONDARY_REGION \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)

# Launch the instance
SECONDARY_INSTANCE_ID=$(aws ec2 run-instances \
  --region $SECONDARY_REGION \
  --image-id $SECONDARY_AMI_ID \
  --instance-type t3.micro \
  --key-name "vpc-challenge-key-$UNIQUE_ID" \
  --security-group-ids $SECONDARY_SG_ID \
  --subnet-id $SECONDARY_SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=SecondaryInstance-$UNIQUE_ID}]" \
  --query "Instances[0].InstanceId" \
  --output text)

# Get the public IP address
SECONDARY_INSTANCE_IP=$(aws ec2 describe-instances \
  --region $SECONDARY_REGION \
  --instance-ids $SECONDARY_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Secondary Instance launched with IP: $SECONDARY_INSTANCE_IP"
```
</details>

### Part 5: Create VPC Peering Connection

Set up VPC peering between your two VPCs across regions. You'll need to:
- Create the peering connection from one region
- Accept the connection from the other region

Requirements:
1. Initiate a VPC peering connection from your primary region to your secondary region
2. Accept the peering connection request in the secondary region
3. Tag your peering connection for identification

<details>
<summary>Click to reveal solution for creating VPC peering connection</summary>

1. Initiate the VPC peering connection from the primary region:

```bash
# Get primary VPC info
PRIMARY_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create VPC peering connection
PEERING_CONNECTION_ID=$(aws ec2 create-vpc-peering-connection \
  --region $PRIMARY_REGION \
  --vpc-id $PRIMARY_VPC_ID \
  --peer-vpc-id $SECONDARY_VPC_ID \
  --peer-owner-id $PRIMARY_ACCOUNT_ID \
  --peer-region $SECONDARY_REGION \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=VPCPeering-$UNIQUE_ID}]" \
  --query "VpcPeeringConnection.VpcPeeringConnectionId" \
  --output text)

echo "Created VPC Peering Connection: $PEERING_CONNECTION_ID"
```

2. Accept the VPC peering connection in the secondary region:

```bash
# Accept the peering connection
aws ec2 accept-vpc-peering-connection \
  --region $SECONDARY_REGION \
  --vpc-peering-connection-id $PEERING_CONNECTION_ID

echo "Accepted VPC Peering Connection"
```
</details>

### Part 6: Update Route Tables

Now that the peering connection is established, you need to update route tables in both VPCs to route traffic to the peer VPC through the peering connection.

Requirements:
1. Add a route in the primary VPC's route table to direct traffic destined for the secondary VPC's CIDR block through the peering connection
2. Add a route in the secondary VPC's route table to direct traffic destined for the primary VPC's CIDR block through the peering connection

<details>
<summary>Click to reveal solution for updating route tables</summary>

1. Add routes to the Primary VPC route table:

```bash
# Add route to the secondary VPC CIDR via the peering connection
aws ec2 create-route \
  --region $PRIMARY_REGION \
  --route-table-id $PRIMARY_RT_ID \
  --destination-cidr-block $SECONDARY_VPC_CIDR \
  --vpc-peering-connection-id $PEERING_CONNECTION_ID

echo "Added route to Secondary VPC CIDR in Primary route table"
```

2. Add routes to the Secondary VPC route table:

```bash
# Add route to the primary VPC CIDR via the peering connection
aws ec2 create-route \
  --region $SECONDARY_REGION \
  --route-table-id $SECONDARY_RT_ID \
  --destination-cidr-block $PRIMARY_VPC_CIDR \
  --vpc-peering-connection-id $PEERING_CONNECTION_ID

echo "Added route to Primary VPC CIDR in Secondary route table"
```
</details>

### Part 7: Test Connectivity

Finally, test connectivity between instances in the different VPCs.

Requirements:
1. Get the private IP addresses of your instances
2. SSH into your primary instance
3. Ping the secondary instance's private IP address
4. SSH into your secondary instance
5. Ping the primary instance's private IP address

<details>
<summary>Click to reveal solution for testing connectivity</summary>

1. Get the private IP addresses of your instances:

```bash
PRIMARY_INSTANCE_PRIVATE_IP=$(aws ec2 describe-instances \
  --region $PRIMARY_REGION \
  --instance-ids $PRIMARY_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)

SECONDARY_INSTANCE_PRIVATE_IP=$(aws ec2 describe-instances \
  --region $SECONDARY_REGION \
  --instance-ids $SECONDARY_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)

echo "Primary Instance Private IP: $PRIMARY_INSTANCE_PRIVATE_IP"
echo "Secondary Instance Private IP: $SECONDARY_INSTANCE_PRIVATE_IP"
```

2. SSH into your primary instance and ping the secondary instance:

```bash
# SSH to primary instance
ssh -i vpc-challenge-key.pem ec2-user@$PRIMARY_INSTANCE_IP

# From within the primary instance, ping the secondary instance
ping $SECONDARY_INSTANCE_PRIVATE_IP
```

3. SSH into your secondary instance and ping the primary instance:

```bash
# SSH to secondary instance
ssh -i vpc-challenge-key.pem ec2-user@$SECONDARY_INSTANCE_IP

# From within the secondary instance, ping the primary instance
ping $PRIMARY_INSTANCE_PRIVATE_IP
```
</details>

## Challenge Extensions

If you complete the basic challenge, try these extensions:

1. **Add a NAT Gateway**: Configure a NAT Gateway in each VPC and place instances in private subnets that can still communicate across regions.

2. **Transfer Files Between Instances**: Set up a simple file transfer between the two instances using SCP or another tool.

3. **Deploy Region-Specific Services**: Deploy a service in each region (e.g., S3 bucket, DynamoDB table) and configure instances to access the local service.

4. **Implement Transit Gateway**: Instead of VPC peering, implement AWS Transit Gateway to connect the VPCs.

5. **Add CloudWatch Monitoring**: Set up CloudWatch alarms to monitor the network traffic between your VPCs.

<details>
<summary>Looking for implementation hints for the challenge extensions?</summary>

### 1. Adding NAT Gateways and Private Subnets

```bash
# For the Primary VPC:
# Create a private subnet
PRIMARY_PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --region $PRIMARY_REGION \
  --vpc-id $PRIMARY_VPC_ID \
  --cidr-block "10.0.2.0/24" \
  --availability-zone "${PRIMARY_REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=PrimaryPrivateSubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

# Allocate Elastic IP for NAT Gateway
PRIMARY_EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --region $PRIMARY_REGION \
  --domain vpc \
  --query "AllocationId" \
  --output text)

# Create NAT Gateway
PRIMARY_NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --region $PRIMARY_REGION \
  --subnet-id $PRIMARY_SUBNET_ID \
  --allocation-id $PRIMARY_EIP_ALLOC_ID \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=PrimaryNATGW-$UNIQUE_ID}]" \
  --query "NatGateway.NatGatewayId" \
  --output text)

# Create private route table
PRIMARY_PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --region $PRIMARY_REGION \
  --vpc-id $PRIMARY_VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=PrimaryPrivateRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

# Wait for NAT Gateway to be available
echo "Waiting for NAT Gateway to be available..."
aws ec2 wait nat-gateway-available \
  --region $PRIMARY_REGION \
  --nat-gateway-ids $PRIMARY_NAT_GW_ID

# Add route through NAT Gateway
aws ec2 create-route \
  --region $PRIMARY_REGION \
  --route-table-id $PRIMARY_PRIVATE_RT_ID \
  --destination-cidr-block "0.0.0.0/0" \
  --nat-gateway-id $PRIMARY_NAT_GW_ID

# Add route to peer VPC
aws ec2 create-route \
  --region $PRIMARY_REGION \
  --route-table-id $PRIMARY_PRIVATE_RT_ID \
  --destination-cidr-block $SECONDARY_VPC_CIDR \
  --vpc-peering-connection-id $PEERING_CONNECTION_ID

# Associate private route table with private subnet
aws ec2 associate-route-table \
  --region $PRIMARY_REGION \
  --subnet-id $PRIMARY_PRIVATE_SUBNET_ID \
  --route-table-id $PRIMARY_PRIVATE_RT_ID
```

### 2. Setting Up File Transfer Between Instances

```bash
# From your local machine, first create a test file
echo "Hello from primary instance!" > test-file.txt

# Upload the file to the primary instance
scp -i vpc-challenge-key.pem test-file.txt ec2-user@$PRIMARY_INSTANCE_IP:~/

# SSH to the primary instance
ssh -i vpc-challenge-key.pem ec2-user@$PRIMARY_INSTANCE_IP

# From the primary instance, transfer the file to the secondary instance
scp -i ~/.ssh/id_rsa test-file.txt ec2-user@$SECONDARY_INSTANCE_PRIVATE_IP:~/

# Check if the file transfer worked
ssh -i ~/.ssh/id_rsa ec2-user@$SECONDARY_INSTANCE_PRIVATE_IP "cat ~/test-file.txt"
```

### 3. Implementing Transit Gateway

```bash
# Create Transit Gateway
TGW_ID=$(aws ec2 create-transit-gateway \
  --region $PRIMARY_REGION \
  --description "Multi-region Transit Gateway" \
  --options "AmazonSideAsn=64512" \
  --tag-specifications "ResourceType=transit-gateway,Tags=[{Key=Name,Value=Challenge-TGW-$UNIQUE_ID}]" \
  --query "TransitGateway.TransitGatewayId" \
  --output text)

# Wait for Transit Gateway to be available
echo "Waiting for Transit Gateway to be available..."
aws ec2 wait transit-gateway-available \
  --region $PRIMARY_REGION \
  --transit-gateway-ids $TGW_ID

# Create attachment for primary VPC
PRIMARY_TGW_ATTACHMENT=$(aws ec2 create-transit-gateway-vpc-attachment \
  --region $PRIMARY_REGION \
  --transit-gateway-id $TGW_ID \
  --vpc-id $PRIMARY_VPC_ID \
  --subnet-ids $PRIMARY_SUBNET_ID \
  --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=Primary-TGW-Attachment-$UNIQUE_ID}]" \
  --query "TransitGatewayVpcAttachment.TransitGatewayAttachmentId" \
  --output text)

# Share TGW with secondary region (for same account)
SECONDARY_TGW_ID=$(aws ec2 create-transit-gateway \
  --region $SECONDARY_REGION \
  --description "Secondary region Transit Gateway" \
  --options "AmazonSideAsn=64513" \
  --tag-specifications "ResourceType=transit-gateway,Tags=[{Key=Name,Value=Challenge-TGW-Secondary-$UNIQUE_ID}]" \
  --query "TransitGateway.TransitGatewayId" \
  --output text)

# Create attachment for secondary VPC
SECONDARY_TGW_ATTACHMENT=$(aws ec2 create-transit-gateway-vpc-attachment \
  --region $SECONDARY_REGION \
  --transit-gateway-id $SECONDARY_TGW_ID \
  --vpc-id $SECONDARY_VPC_ID \
  --subnet-ids $SECONDARY_SUBNET_ID \
  --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=Secondary-TGW-Attachment-$UNIQUE_ID}]" \
  --query "TransitGatewayVpcAttachment.TransitGatewayAttachmentId" \
  --output text)
```

### 4. Setting Up CloudWatch Monitoring

```bash
# Create CloudWatch alarm for network traffic between VPCs
aws cloudwatch put-metric-alarm \
  --region $PRIMARY_REGION \
  --alarm-name "VPC-Peering-NetworkTraffic-$UNIQUE_ID" \
  --alarm-description "Alarm for network traffic between peered VPCs" \
  --metric-name "PacketsTransmitted" \
  --namespace "AWS/EC2" \
  --statistic Sum \
  --dimensions "Name=InstanceId,Value=$PRIMARY_INSTANCE_ID" \
  --period 300 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions "arn:aws:sns:$PRIMARY_REGION:$PRIMARY_ACCOUNT_ID:default" \
  --insufficient-data-actions []
```
</details>

## Cleanup

Don't forget to clean up your resources when you're done to avoid unnecessary charges!

<details>
<summary>Click to reveal cleanup instructions</summary>

```bash
# Delete instances
aws ec2 terminate-instances --region $PRIMARY_REGION --instance-ids $PRIMARY_INSTANCE_ID
aws ec2 terminate-instances --region $SECONDARY_REGION --instance-ids $SECONDARY_INSTANCE_ID

# Wait for instances to terminate
echo "Waiting for instances to terminate..."
aws ec2 wait instance-terminated --region $PRIMARY_REGION --instance-ids $PRIMARY_INSTANCE_ID
aws ec2 wait instance-terminated --region $SECONDARY_REGION --instance-ids $SECONDARY_INSTANCE_ID

# Delete VPC peering connection
aws ec2 delete-vpc-peering-connection --region $PRIMARY_REGION --vpc-peering-connection-id $PEERING_CONNECTION_ID

# Delete security groups
aws ec2 delete-security-group --region $PRIMARY_REGION --group-id $PRIMARY_SG_ID
aws ec2 delete-security-group --region $SECONDARY_REGION --group-id $SECONDARY_SG_ID

# Detach and delete Internet Gateways
aws ec2 detach-internet-gateway --region $PRIMARY_REGION --internet-gateway-id $PRIMARY_IGW_ID --vpc-id $PRIMARY_VPC_ID
aws ec2 delete-internet-gateway --region $PRIMARY_REGION --internet-gateway-id $PRIMARY_IGW_ID

aws ec2 detach-internet-gateway --region $SECONDARY_REGION --internet-gateway-id $SECONDARY_IGW_ID --vpc-id $SECONDARY_VPC_ID
aws ec2 delete-internet-gateway --region $SECONDARY_REGION --internet-gateway-id $SECONDARY_IGW_ID

# Delete route tables
aws ec2 delete-route-table --region $PRIMARY_REGION --route-table-id $PRIMARY_RT_ID
aws ec2 delete-route-table --region $SECONDARY_REGION --route-table-id $SECONDARY_RT_ID

# Delete subnets
aws ec2 delete-subnet --region $PRIMARY_REGION --subnet-id $PRIMARY_SUBNET_ID
aws ec2 delete-subnet --region $SECONDARY_REGION --subnet-id $SECONDARY_SUBNET_ID

# Delete VPCs
aws ec2 delete-vpc --region $PRIMARY_REGION --vpc-id $PRIMARY_VPC_ID
aws ec2 delete-vpc --region $SECONDARY_REGION --vpc-id $SECONDARY_VPC_ID

# Delete key pair
aws ec2 delete-key-pair --region $PRIMARY_REGION --key-name "vpc-challenge-key-$UNIQUE_ID"
aws ec2 delete-key-pair --region $SECONDARY_REGION --key-name "vpc-challenge-key-$UNIQUE_ID"
rm vpc-challenge-key.pem

echo "All resources have been cleaned up!"
```
</details>

## Troubleshooting Tips

- **DNS Resolution**: Make sure DNS resolution is enabled on both VPCs for the peering connection to work properly.
- **Security Groups**: Ensure that security groups on both sides allow the required traffic.
- **Route Tables**: Verify that route tables in both VPCs have the correct routes to the peer VPC.
- **Network ACLs**: Check that network ACLs don't block traffic between the VPCs.
- **EC2 Instance Status**: Ensure that instances are in the 'running' state before testing connectivity.
- **Region-Specific Settings**: Note that some AWS resource IDs and AMIs may vary between regions. 

<details>
<summary>Advanced Troubleshooting Guide</summary>

### Common Issues and Solutions

1. **VPC Peering Connection Stays in "Pending Acceptance" State**
   - Verify that you're using the correct VPC peering connection ID in the acceptance command
   - Check that you have the correct permissions in both regions
   - Ensure you're running the acceptance command in the correct (peer) region

2. **Unable to Ping Across VPCs**
   - Verify DNS hostnames and DNS resolution are enabled on both VPCs
   - Check that security groups in both VPCs allow ICMP traffic from the peer VPC's CIDR
   - Verify that the route tables in both VPCs have routes to the peer VPC via the peering connection
   - Check that you're using the correct private IP addresses for your instances
   - Ensure there are no network ACLs blocking ICMP traffic

3. **Key Pair Issues**
   - If you see "Permission denied (publickey)" when trying to SSH, check that:
     - The key pair was correctly created and imported to both regions
     - The permissions on the key file are correct (chmod 400)
     - You're using the correct username (ec2-user for Amazon Linux)

4. **Route Table Configuration**
   - To verify your route tables are configured correctly:
   ```bash
   # Check primary route table
   aws ec2 describe-route-tables --region $PRIMARY_REGION --route-table-id $PRIMARY_RT_ID
   
   # Check secondary route table
   aws ec2 describe-route-tables --region $SECONDARY_REGION --route-table-id $SECONDARY_RT_ID
   ```

5. **Cross-Region Peering Limitations**
   - Cross-region peering doesn't support IPv6 traffic
   - DNS resolution for private DNS hostnames is not automatically enabled (requires additional configuration)
   - Security group references can't span peering connections
   - Maximum MTU (packet size) is 1500 bytes (jumbo frames not supported)

6. **VPC Peering Connection Status**
   - To check the status of your peering connection:
   ```bash
   aws ec2 describe-vpc-peering-connections \
     --region $PRIMARY_REGION \
     --vpc-peering-connection-ids $PEERING_CONNECTION_ID
   ```
</details> 