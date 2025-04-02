# AWS VPC Lab using AWS CLI

## Lab Overview
In this lab, you will create a Virtual Private Cloud (VPC) environment using the AWS CLI. You'll learn how to:
- Create a VPC with custom CIDR block
- Add public and private subnets
- Configure Internet Gateway for public internet access
- Set up route tables to control traffic flow
- Create security groups for network security

## Prerequisites
- AWS account with access to CloudShell or AL2023 environment
- Basic understanding of networking concepts
- Familiarity with basic AWS CLI commands

## Time to Complete
Approximately 30-45 minutes

## Step 1: Launch AWS CloudShell

1. Log in to your AWS account
2. In the AWS Management Console, click the CloudShell icon in the navigation bar at the top
3. Wait for CloudShell to initialize

## Step 2: Create a Resource Tracking File

First, let's create a file to track all the resources we create:

```bash
# Create a directory for our lab
mkdir -p ~/vpc-lab
RESOURCE_FILE=~/vpc-lab/resources.txt
touch $RESOURCE_FILE

# Set the AWS region and add to our resource file
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"  # Default to us-east-1 if no region set
fi
echo "AWS_REGION=$AWS_REGION" >> $RESOURCE_FILE

# Generate a unique identifier to avoid name conflicts
UNIQUE_ID=$(date +%Y%m%d%H%M%S)
echo "UNIQUE_ID=$UNIQUE_ID" >> $RESOURCE_FILE
```

This tracking file will help us keep track of all the resource IDs we create during the lab.

## Step 3: Create a VPC

Let's create a VPC with a CIDR block of 10.0.0.0/16:

```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=MyLabVPC-$UNIQUE_ID}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "Created VPC: $VPC_ID"
echo "VPC_ID=$VPC_ID" >> $RESOURCE_FILE
```

What's happening here:
- We're creating a new VPC with a CIDR block of 10.0.0.0/16 (65,536 IP addresses)
- We're adding a Name tag to easily identify our VPC in the AWS console
- We're extracting the VPC ID from the response and saving it to our resource file

## Step 4: Enable DNS Support in the VPC

For our VPC to work properly with DNS, let's enable DNS support:

```bash
# Enable DNS hostnames and DNS support for the VPC
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}"

echo "Enabled DNS hostnames and support for the VPC"
```

These commands allow instances in our VPC to resolve public DNS hostnames to private IP addresses.

## Step 5: Create Subnets

Now, let's create public and private subnets in different availability zones:

```bash
# Get available availability zones in the region
AZS=$(aws ec2 describe-availability-zones \
  --region "$AWS_REGION" \
  --query "AvailabilityZones[?State=='available'].ZoneName" \
  --output text)

# Create an array of AZs
AZ_ARR=($AZS)

echo "Available AZs: ${AZ_ARR[@]}"
```

Now that we have the available AZs, let's create our public subnet:

```bash
# Create public subnet in the first AZ
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone "${AZ_ARR[0]}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

echo "Created Public Subnet: $PUBLIC_SUBNET_ID in AZ: ${AZ_ARR[0]}"
echo "PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID" >> $RESOURCE_FILE
echo "PUBLIC_SUBNET_AZ=${AZ_ARR[0]}" >> $RESOURCE_FILE
```

Next, let's create a private subnet:

```bash
# Create private subnet in the second AZ
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone "${AZ_ARR[1]}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet-$UNIQUE_ID}]" \
  --query "Subnet.SubnetId" \
  --output text)

echo "Created Private Subnet: $PRIVATE_SUBNET_ID in AZ: ${AZ_ARR[1]}"
echo "PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID" >> $RESOURCE_FILE
echo "PRIVATE_SUBNET_AZ=${AZ_ARR[1]}" >> $RESOURCE_FILE
```

Here's what we've done:
- Created a public subnet with CIDR 10.0.1.0/24 (256 IP addresses) in the first AZ
- Created a private subnet with CIDR 10.0.2.0/24 (256 IP addresses) in the second AZ
- Both subnets are tagged for easy identification

## Step 6: Create and Attach Internet Gateway

For our public subnet to have internet access, we need an Internet Gateway:

```bash
# Create an Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=MyLabIGW-$UNIQUE_ID}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

echo "Created Internet Gateway: $IGW_ID"
echo "IGW_ID=$IGW_ID" >> $RESOURCE_FILE
```

Now we need to attach it to our VPC:

```bash
# Attach the Internet Gateway to the VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

echo "Attached Internet Gateway to VPC"
```

The Internet Gateway acts as a bridge between our VPC and the internet, allowing resources in the public subnet to connect to the internet.

## Step 7: Configure Route Tables

Now we need to set up route tables to direct traffic properly:

```bash
# Create a route table for the public subnet
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=PublicRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

echo "Created Public Route Table: $PUBLIC_ROUTE_TABLE_ID"
echo "PUBLIC_ROUTE_TABLE_ID=$PUBLIC_ROUTE_TABLE_ID" >> $RESOURCE_FILE
```

Let's add a route to the internet via our Internet Gateway:

```bash
# Create a route to the Internet Gateway
aws ec2 create-route \
  --route-table-id "$PUBLIC_ROUTE_TABLE_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"

echo "Added internet route to Public Route Table"
```

Now we need to associate this route table with our public subnet:

```bash
# Associate the public route table with the public subnet
aws ec2 associate-route-table \
  --route-table-id "$PUBLIC_ROUTE_TABLE_ID" \
  --subnet-id "$PUBLIC_SUBNET_ID"

echo "Associated Public Route Table with Public Subnet"
```

Let's create a private route table for our private subnet:

```bash
# Create a route table for the private subnet
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=PrivateRT-$UNIQUE_ID}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

echo "Created Private Route Table: $PRIVATE_ROUTE_TABLE_ID"
echo "PRIVATE_ROUTE_TABLE_ID=$PRIVATE_ROUTE_TABLE_ID" >> $RESOURCE_FILE

# Associate the private route table with the private subnet
aws ec2 associate-route-table \
  --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID"

echo "Associated Private Route Table with Private Subnet"
```

What we've done:
- Created a public route table with a route to the internet (0.0.0.0/0) via the Internet Gateway
- Associated this route table with our public subnet
- Created a private route table (without internet access)
- Associated the private route table with our private subnet

## Step 8: Enable Auto-assign Public IP for Public Subnet

For instances in the public subnet to automatically receive public IPs:

```bash
# Enable auto-assign public IP on the public subnet
aws ec2 modify-subnet-attribute \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --map-public-ip-on-launch

echo "Enabled auto-assign public IP on the Public Subnet"
```

This ensures that any EC2 instance launched in the public subnet will automatically receive a public IP address.

## Step 9: Create Security Groups

Let's create a security group for instances in the public subnet:

```bash
# Create security group for public instances
PUBLIC_SG_ID=$(aws ec2 create-security-group \
  --group-name "public-sg-$UNIQUE_ID" \
  --description "Security group for public instances" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" \
  --output text)

echo "Created Public Security Group: $PUBLIC_SG_ID"
echo "PUBLIC_SG_ID=$PUBLIC_SG_ID" >> $RESOURCE_FILE
```

Now, let's add rules to allow SSH access and all outbound traffic:

```bash
# Add SSH inbound rule to public security group
aws ec2 authorize-security-group-ingress \
  --group-id "$PUBLIC_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "Added SSH ingress rule to Public Security Group"
```

Let's create a security group for instances in the private subnet:

```bash
# Create security group for private instances
PRIVATE_SG_ID=$(aws ec2 create-security-group \
  --group-name "private-sg-$UNIQUE_ID" \
  --description "Security group for private instances" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" \
  --output text)

echo "Created Private Security Group: $PRIVATE_SG_ID"
echo "PRIVATE_SG_ID=$PRIVATE_SG_ID" >> $RESOURCE_FILE
```

Add a rule to allow SSH access from the public subnet to the private subnet:

```bash
# Add SSH inbound rule to private security group from public security group
aws ec2 authorize-security-group-ingress \
  --group-id "$PRIVATE_SG_ID" \
  --protocol tcp \
  --port 22 \
  --source-group "$PUBLIC_SG_ID"

echo "Added SSH ingress rule to Private Security Group from Public Security Group"
```

What we've done:
- Created a security group for public instances that allows SSH access from anywhere
- Created a security group for private instances that allows SSH access only from instances in the public security group

## Step 10: Deploy EC2 Instances to Test Routing

Now that we have our VPC infrastructure set up, let's launch EC2 instances to demonstrate how routing works between public and private subnets:

### Step 10.1: Create a Key Pair for SSH Access

First, let's create a key pair for SSH access to our instances:

```bash
# Create a key pair
KEY_NAME="vpc-lab-key-$UNIQUE_ID"
aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --query "KeyMaterial" \
  --output text > $KEY_NAME.pem
```

```bash
# Set proper permissions for the key file
chmod 400 $KEY_NAME.pem
```

```bash
echo "KEY_NAME=$KEY_NAME" >> $RESOURCE_FILE
echo "Created key pair: $KEY_NAME"
```

### Step 10.2: Add ICMP to Security Groups

Let's update the security groups to allow ICMP (ping) traffic for our connectivity tests:

```bash
# Allow ICMP in the public security group
aws ec2 authorize-security-group-ingress \
  --group-id "$PUBLIC_SG_ID" \
  --protocol icmp \
  --port -1 \
  --cidr 0.0.0.0/0
```

```bash
# Allow ICMP from public to private security group
aws ec2 authorize-security-group-ingress \
  --group-id "$PRIVATE_SG_ID" \
  --protocol icmp \
  --port -1 \
  --source-group "$PUBLIC_SG_ID"
```

```bash
echo "Added ICMP rules to security groups"
```

### Step 10.3: Create User Data Scripts

Let's create scripts that will automatically test connectivity when our instances launch:

```bash
# Create user data for public instance that will prepare it for testing
cat > public_user_data.txt << 'EOF'
#!/bin/bash
# Install required tools
yum update -y
yum install -y nc jq

# Create a helper script to test connectivity
cat > /home/ec2-user/test_connectivity.sh << 'INNERSCRIPT'
#!/bin/bash
echo "===== Instance Details ====="
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"

echo -e "\n===== Testing Internet Connectivity ====="
echo "Pinging amazon.com:"
ping -c 3 amazon.com

echo -e "\n===== Testing VPC Internal Routing ====="
echo "Pinging private instance at $1:"
ping -c 3 $1
INNERSCRIPT

chmod +x /home/ec2-user/test_connectivity.sh
chown ec2-user:ec2-user /home/ec2-user/test_connectivity.sh

# Create a welcome message with instructions
cat > /etc/motd << 'MOTD'
=======================================================================
Welcome to the VPC Lab Public Instance!

To test connectivity to the private instance, run:
  ./test_connectivity.sh <PRIVATE_INSTANCE_IP>

To SSH to the private instance, run:
  ssh ec2-user@<PRIVATE_INSTANCE_IP>
=======================================================================
MOTD
EOF
```

```bash
# Create user data for private instance
cat > private_user_data.txt << 'EOF'
#!/bin/bash
# Install required tools
yum update -y
yum install -y nc jq

# Create a helper script to test internet connectivity
cat > /home/ec2-user/test_internet.sh << 'INNERSCRIPT'
#!/bin/bash
echo "===== Instance Details ====="
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"

echo -e "\n===== Testing Internet Connectivity ====="
echo "Pinging amazon.com:"
ping -c 2 -w 5 amazon.com
if [ $? -ne 0 ]; then
  echo "Cannot reach internet from private subnet (expected behavior)"
else
  echo "Reached internet from private subnet (unexpected)"
fi
INNERSCRIPT

chmod +x /home/ec2-user/test_internet.sh
chown ec2-user:ec2-user /home/ec2-user/test_internet.sh

# Create a welcome message with instructions
cat > /etc/motd << 'MOTD'
=======================================================================
Welcome to the VPC Lab Private Instance!

To test internet connectivity, run:
  ./test_internet.sh
=======================================================================
MOTD
EOF
```

### Step 10.4: Launch an Instance in the Public Subnet

Now, let's launch an EC2 instance in the public subnet:

```bash
# Get the latest Amazon Linux 2 AMI ID
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)
```

```bash
# Configure SSH key setup for the private instance
cat >> public_user_data.txt << EOF
# Copy SSH key to allow access to private instance
cat > /home/ec2-user/.ssh/id_rsa << 'PRIVATEKEY'
$(cat $KEY_NAME.pem)
PRIVATEKEY
chmod 600 /home/ec2-user/.ssh/id_rsa
chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
EOF
```

```bash
# Launch instance in public subnet with user data
PUBLIC_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name "$KEY_NAME" \
  --security-group-ids "$PUBLIC_SG_ID" \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --user-data file://public_user_data.txt \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=PublicInstance-$UNIQUE_ID}]" \
  --query "Instances[0].InstanceId" \
  --output text)
```

```bash
echo "PUBLIC_INSTANCE_ID=$PUBLIC_INSTANCE_ID" >> $RESOURCE_FILE
echo "Launched Public EC2 Instance: $PUBLIC_INSTANCE_ID"
```

### Step 10.5: Launch an Instance in the Private Subnet

Next, let's launch an EC2 instance in the private subnet:

```bash
# Launch instance in private subnet with user data
PRIVATE_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name "$KEY_NAME" \
  --security-group-ids "$PRIVATE_SG_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID" \
  --user-data file://private_user_data.txt \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=PrivateInstance-$UNIQUE_ID}]" \
  --query "Instances[0].InstanceId" \
  --output text)
```

```bash
echo "PRIVATE_INSTANCE_ID=$PRIVATE_INSTANCE_ID" >> $RESOURCE_FILE
echo "Launched Private EC2 Instance: $PRIVATE_INSTANCE_ID"
```

### Step 10.6: Wait for Instances to be Ready

Let's wait for our instances to be in a running state:

```bash
# Wait for instances to be running
echo "Waiting for instances to be in running state..."
aws ec2 wait instance-running --instance-ids "$PUBLIC_INSTANCE_ID" "$PRIVATE_INSTANCE_ID"
```

```bash
# Get public IP of the public instance
PUBLIC_INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids "$PUBLIC_INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)
```

```bash
# Get private IPs of both instances
PUBLIC_INSTANCE_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids "$PUBLIC_INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)
```

```bash
PRIVATE_INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids "$PRIVATE_INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)
```

```bash
echo "Public Instance Public IP: $PUBLIC_INSTANCE_IP"
echo "Public Instance Private IP: $PUBLIC_INSTANCE_PRIVATE_IP"
echo "Private Instance IP: $PRIVATE_INSTANCE_IP"
# Wait a bit more for user data script to complete
echo "Waiting for user data scripts to complete..."
sleep 30
```

### Step 10.7: Test Connectivity and Routing

Now, let's create instructions for testing connectivity:

```bash
# Display the connection information for testing
echo -e "\n===================================================================="
echo "To test connectivity between instances:"
echo ""
echo "1. First, connect to the public instance:"
echo "   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_INSTANCE_IP"
echo ""
echo "2. Once connected to the public instance, test internet connectivity:"
echo "   ping -c 3 amazon.com"
echo ""
echo "3. Test connectivity to the private instance:"
echo "   ping -c 3 $PRIVATE_INSTANCE_IP"
echo ""
echo "4. Connect to the private instance from the public instance:"
echo "   ssh ec2-user@$PRIVATE_INSTANCE_IP"
echo ""
echo "5. On the private instance, test internet connectivity (should fail):"
echo "   ./test_internet.sh"
echo ""
echo "6. Exit back to the public instance:"
echo "   exit"
echo ""
echo "7. Exit back to your CloudShell:"
echo "   exit"
echo "===================================================================="
```

This approach:
1. Provides clear, step-by-step instructions for manual testing
2. Shows the exact commands to run at each step
3. Explains what to expect at each testing stage

## Step 11: Verify Our VPC Setup

Let's check our VPC configuration:

```bash
# Describe our VPC
aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --query "Vpcs[0]" | cat
```

```bash
# List all subnets in our VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone,Tags:Tags}" | cat
```

Let's also check our route tables:

```bash
# Describe public route table
aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_ROUTE_TABLE_ID" \
  --query "RouteTables[0]" | cat
```

```bash
# Describe private route table
aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_ROUTE_TABLE_ID" \
  --query "RouteTables[0]" | cat
```

## Step 12: Cleanup Resources

When you're done with the lab, clean up all resources to avoid unexpected charges:

```bash
# Terminate EC2 instances
aws ec2 terminate-instances --instance-ids "$PUBLIC_INSTANCE_ID" "$PRIVATE_INSTANCE_ID"
```

```bash
# Wait for instances to terminate
echo "Waiting for instances to terminate..."
aws ec2 wait instance-terminated --instance-ids "$PUBLIC_INSTANCE_ID" "$PRIVATE_INSTANCE_ID"
```

```bash
# Delete key pair
aws ec2 delete-key-pair --key-name "$KEY_NAME"
rm -f $KEY_NAME.pem
```

```bash
# Delete security groups
aws ec2 delete-security-group --group-id "$PUBLIC_SG_ID"
```

```bash
aws ec2 delete-security-group --group-id "$PRIVATE_SG_ID"
```

Delete route tables and their associations:

```bash
# Delete route tables (associations are deleted automatically)
aws ec2 delete-route-table --route-table-id "$PRIVATE_ROUTE_TABLE_ID"
```

```bash
aws ec2 delete-route-table --route-table-id "$PUBLIC_ROUTE_TABLE_ID"
```

Detach and delete the Internet Gateway:

```bash
# Detach Internet Gateway from VPC
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"
```

```bash
# Delete Internet Gateway
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
```

Delete subnets and the VPC:

```bash
# Delete subnets
aws ec2 delete-subnet --subnet-id "$PUBLIC_SUBNET_ID"
```

```bash
aws ec2 delete-subnet --subnet-id "$PRIVATE_SUBNET_ID"
```

```bash
# Delete VPC
aws ec2 delete-vpc --vpc-id "$VPC_ID"
```

```bash
# Remove local files created during the lab
rm -f public_user_data.txt private_user_data.txt test_commands.txt
```

## Troubleshooting

### Common Issues:

1. **Resource Already Exists**
   - Use unique identifiers for resource names
   - Check if resources already exist before creating them
   - If needed, use a different region or clean up existing resources

2. **Permission Errors**
   - Verify your AWS CLI credentials are configured correctly
   - Ensure you have the necessary IAM permissions
   - If in CloudShell, ensure you have appropriate IAM roles

3. **Resource Dependencies**
   - Resources must be deleted in the correct order
   - You cannot delete a VPC with attached resources
   - Check for dependencies before attempting to delete resources

## Extended Learning

Try these additional challenges:
1. Create a NAT Gateway in the public subnet to provide internet access to instances in the private subnet
2. Launch EC2 instances in both public and private subnets
3. Configure VPC Flow Logs to monitor network traffic
4. Set up a bastion host in the public subnet for secure access to private instances
5. Create a VPC endpoint for S3 to allow private instances to access S3 without going through the internet

## References
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [AWS CLI EC2 Commands](https://docs.aws.amazon.com/cli/latest/reference/ec2/index.html)
- [VPC Subnet Sizing](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html)

## Terraform Implementation

This lab also includes a Terraform implementation in the `/terraform` directory. If you prefer to use Infrastructure as Code instead of CLI commands, check out the README.md file in that directory for instructions on how to deploy the same VPC infrastructure using Terraform.
