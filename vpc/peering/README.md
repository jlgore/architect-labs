# AWS VPC Peering Lab

This lab demonstrates how to create and configure VPC peering connections between two VPCs using the AWS CLI. VPC peering allows you to connect two VPCs, enabling resources in either VPC to communicate with each other as if they are in the same network.

## Prerequisites

- AWS CLI installed and configured
- Access to an AWS account with appropriate permissions
- Basic understanding of VPC concepts

## Lab Objectives

- Create two VPCs with different CIDR blocks
- Create subnets in each VPC
- Create a VPC peering connection between the two VPCs
- Configure route tables to allow traffic between the VPCs
- Launch EC2 instances in each VPC to test connectivity

## Sandbox Restrictions

This lab is designed to work within the AWS Academy Cloud Architecting sandbox environment, which has the following restrictions:

### EC2 Instance Restrictions
- Only the following instance types can be launched: t2.nano, t2.micro, t2.small, t2.medium, t3.nano, t3.micro, t3.small, t3.medium
- EBS volumes limited to 35 GB and type General Purpose SSD (gp2)
- On-Demand instances only
- Amazon provided Linux and Windows AMIs only
- Maximum of 9 instances per account

### VPC and Networking
- Standard VPC and networking features are available
- No restrictions on VPC peering connections

## Lab Steps

### 1. Create Two VPCs

In this step, we'll create two Virtual Private Clouds (VPCs) with different, non-overlapping CIDR blocks. VPCs are isolated networks within AWS that provide a foundation for launching AWS resources. We'll create VPC-A with a 10.0.0.0/16 CIDR and VPC-B with 172.16.0.0/16 CIDR, ensuring they don't have overlapping IP address ranges (a requirement for VPC peering).

```bash
# Create the first VPC with a 10.0.0.0/16 CIDR block (offering 65,536 IP addresses)
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPC-A}]'

# Create the second VPC with a 172.16.0.0/16 CIDR block (offering another 65,536 IP addresses)
aws ec2 create-vpc --cidr-block 172.16.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPC-B}]'
```

### 2. Store VPC IDs in Variables

After creating the VPCs, we need to store their IDs in shell variables for easy reference in subsequent commands. We'll use AWS CLI queries with filters to find the VPCs by their name tags and extract just their IDs.

```bash
# Store VPC-A ID in a variable by querying for VPCs with the name tag "VPC-A"
VPC_A_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=VPC-A" --query "Vpcs[0].VpcId" --output text)
echo "VPC-A ID: $VPC_A_ID"

# Store VPC-B ID in a variable by querying for VPCs with the name tag "VPC-B"
VPC_B_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=VPC-B" --query "Vpcs[0].VpcId" --output text)
echo "VPC-B ID: $VPC_B_ID"
```

### 3. Create Subnets in Each VPC

Now we'll create subnets within each VPC. A subnet is a segment of a VPC's IP address range where you can place groups of isolated resources. We'll create one subnet in each VPC, both in the same availability zone (us-east-1a) to ensure low-latency communication between instances.

```bash
# Create a subnet in VPC-A with a smaller CIDR block (10.0.1.0/24 provides 256 IP addresses)
aws ec2 create-subnet --vpc-id $VPC_A_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subnet-A}]'

# Create a subnet in VPC-B with a smaller CIDR block (172.16.1.0/24 provides 256 IP addresses)
aws ec2 create-subnet --vpc-id $VPC_B_ID --cidr-block 172.16.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subnet-B}]'
```

### 4. Store Subnet IDs in Variables

Similar to storing VPC IDs, we'll now store the subnet IDs in variables for later use. This makes our subsequent commands cleaner and less prone to errors.

```bash
# Store Subnet-A ID in a variable by querying for subnets with the name tag "Subnet-A"
SUBNET_A_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=Subnet-A" --query "Subnets[0].SubnetId" --output text)
echo "Subnet-A ID: $SUBNET_A_ID"

# Store Subnet-B ID in a variable by querying for subnets with the name tag "Subnet-B"
SUBNET_B_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=Subnet-B" --query "Subnets[0].SubnetId" --output text)
echo "Subnet-B ID: $SUBNET_B_ID"
```

### 5. Create Internet Gateways

Internet Gateways (IGWs) allow communication between instances in your VPC and the internet. We need to create and attach an IGW to each VPC to allow our instances to connect to the internet and to allow us to SSH into them.

```bash
# Create an Internet Gateway for VPC-A
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=IGW-A}]'
# Get the IGW ID and store it in a variable
IGW_A_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=IGW-A" --query "InternetGateways[0].InternetGatewayId" --output text)
# Attach the IGW to VPC-A
aws ec2 attach-internet-gateway --vpc-id $VPC_A_ID --internet-gateway-id $IGW_A_ID

# Create an Internet Gateway for VPC-B
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=IGW-B}]'
# Get the IGW ID and store it in a variable
IGW_B_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=IGW-B" --query "InternetGateways[0].InternetGatewayId" --output text)
# Attach the IGW to VPC-B
aws ec2 attach-internet-gateway --vpc-id $VPC_B_ID --internet-gateway-id $IGW_B_ID
```

### 6. Create Route Tables

Route tables control where network traffic is directed. Each subnet in your VPC must be associated with a route table, which defines the routes for outbound traffic. Here, we'll create route tables for each VPC, add routes to the internet via the IGWs, and associate them with our subnets.

```bash
# Create a Route Table for VPC-A
aws ec2 create-route-table --vpc-id $VPC_A_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Route-Table-A}]'
# Get the Route Table ID and store it in a variable
RT_A_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=Route-Table-A" --query "RouteTables[0].RouteTableId" --output text)

# Add a route to the internet (0.0.0.0/0) via the Internet Gateway for VPC-A
aws ec2 create-route --route-table-id $RT_A_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_A_ID

# Associate the Route Table with Subnet-A
aws ec2 associate-route-table --route-table-id $RT_A_ID --subnet-id $SUBNET_A_ID

# Create a Route Table for VPC-B
aws ec2 create-route-table --vpc-id $VPC_B_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Route-Table-B}]'
# Get the Route Table ID and store it in a variable
RT_B_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=Route-Table-B" --query "RouteTables[0].RouteTableId" --output text)

# Add a route to the internet (0.0.0.0/0) via the Internet Gateway for VPC-B
aws ec2 create-route --route-table-id $RT_B_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_B_ID

# Associate the Route Table with Subnet-B
aws ec2 associate-route-table --route-table-id $RT_B_ID --subnet-id $SUBNET_B_ID
```

### 7. Create a VPC Peering Connection

A VPC peering connection is a networking connection between two VPCs that enables routing using private IP addresses as if they were part of the same network. In this step, we'll create a peering connection between VPC-A and VPC-B and then accept it (both actions are needed because peering requires a request and acceptance).

```bash
# Create a peering connection from VPC-A to VPC-B
aws ec2 create-vpc-peering-connection --vpc-id $VPC_A_ID --peer-vpc-id $VPC_B_ID --tag-specifications 'ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=VPC-A-to-VPC-B}]'
# Get the peering connection ID and store it in a variable
PEER_ID=$(aws ec2 describe-vpc-peering-connections --filters "Name=tag:Name,Values=VPC-A-to-VPC-B" --query "VpcPeeringConnections[0].VpcPeeringConnectionId" --output text)

# Accept the peering connection - in a real-world scenario where different accounts own the VPCs, 
# the owner of the accepter VPC would need to run this command
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEER_ID
```

### 8. Configure Route Tables for Peering

Just creating a peering connection isn't enough - we need to update our route tables to direct traffic through the peering connection. We'll add routes to each VPC's route table that direct traffic destined for the other VPC's CIDR range through the peering connection.

```bash
# Add a route in VPC-A's route table to send traffic destined for VPC-B's CIDR block through the peering connection
aws ec2 create-route --route-table-id $RT_A_ID --destination-cidr-block 172.16.0.0/16 --vpc-peering-connection-id $PEER_ID

# Add a route in VPC-B's route table to send traffic destined for VPC-A's CIDR block through the peering connection
aws ec2 create-route --route-table-id $RT_B_ID --destination-cidr-block 10.0.0.0/16 --vpc-peering-connection-id $PEER_ID
```

### 9. Create Security Groups

Security groups act as virtual firewalls that control inbound and outbound traffic to your instances. We'll create security groups for each VPC with rules that allow SSH access from anywhere and ICMP (ping) traffic from the other VPC, which is necessary for our connectivity test.

```bash
# Create a Security Group for VPC-A
aws ec2 create-security-group --group-name Security-Group-A --description "Security group for VPC A" --vpc-id $VPC_A_ID
# Get the Security Group ID and store it in a variable
SG_A_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=Security-Group-A" --query "SecurityGroups[0].GroupId" --output text)

# Add rules to Security Group A:
# Allow SSH (port 22) access from anywhere
aws ec2 authorize-security-group-ingress --group-id $SG_A_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
# Allow ICMP (ping) from VPC-B's CIDR block
aws ec2 authorize-security-group-ingress --group-id $SG_A_ID --protocol icmp --port -1 --cidr 172.16.0.0/16
# Allow all outbound traffic
aws ec2 authorize-security-group-egress --group-id $SG_A_ID --protocol -1 --port -1 --cidr 0.0.0.0/0

# Create a Security Group for VPC-B
aws ec2 create-security-group --group-name Security-Group-B --description "Security group for VPC B" --vpc-id $VPC_B_ID
# Get the Security Group ID and store it in a variable
SG_B_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=Security-Group-B" --query "SecurityGroups[0].GroupId" --output text)

# Add rules to Security Group B:
# Allow SSH (port 22) access from anywhere
aws ec2 authorize-security-group-ingress --group-id $SG_B_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
# Allow ICMP (ping) from VPC-A's CIDR block
aws ec2 authorize-security-group-ingress --group-id $SG_B_ID --protocol icmp --port -1 --cidr 10.0.0.0/16
# Allow all outbound traffic
aws ec2 authorize-security-group-egress --group-id $SG_B_ID --protocol -1 --port -1 --cidr 0.0.0.0/0
```

### 10. Launch EC2 Instances in Each VPC

Now we'll launch EC2 instances in each VPC to test the peering connection. We'll use t2.micro instances (which are free tier eligible and sandbox-compatible) running Amazon Linux 2 and the "vockey" key pair provided by the sandbox environment.

```bash
# Launch an EC2 instance in VPC-A
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --key-name vockey --subnet-id $SUBNET_A_ID --security-group-ids $SG_A_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-A}]'
# Get the instance ID and store it in a variable
INSTANCE_A_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Instance-A" "Name=instance-state-name,Values=pending,running" --query "Reservations[0].Instances[0].InstanceId" --output text)

# Launch an EC2 instance in VPC-B
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --key-name vockey --subnet-id $SUBNET_B_ID --security-group-ids $SG_B_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-B}]'
# Get the instance ID and store it in a variable
INSTANCE_B_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Instance-B" "Name=instance-state-name,Values=pending,running" --query "Reservations[0].Instances[0].InstanceId" --output text)
```

### 11. Wait for Instances to be Running

EC2 instances take a short time to initialize. We'll use the AWS CLI's wait command to pause execution until our instances are fully running before we attempt to test connectivity.

```bash
# Wait for Instance-A to reach the 'running' state - this pauses the script until the instance is ready
aws ec2 wait instance-running --instance-ids $INSTANCE_A_ID
echo "Instance-A is now running"

# Wait for Instance-B to reach the 'running' state
aws ec2 wait instance-running --instance-ids $INSTANCE_B_ID
echo "Instance-B is now running"
```

### 12. Test Connectivity

Finally, we'll test the VPC peering connection by trying to ping from one instance to the other. If our peering connection and all associated configurations (routes, security groups) are set up correctly, the ping should succeed.

```bash
# Get the private IP addresses of both instances
INSTANCE_A_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_A_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
INSTANCE_B_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_B_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

# Get the public IP address of Instance-A (which we'll use to SSH into)
INSTANCE_A_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_A_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo "Instance-A Private IP: $INSTANCE_A_PRIVATE_IP"
echo "Instance-B Private IP: $INSTANCE_B_PRIVATE_IP"
echo "Instance-A Public IP: $INSTANCE_A_PUBLIC_IP"

# The command below will SSH into Instance-A and ping Instance-B's private IP address
# If successful, this confirms that traffic is flowing through the VPC peering connection
echo "To test connectivity, run:"
echo "ssh -i labsuser.pem ec2-user@$INSTANCE_A_PUBLIC_IP 'ping -c 4 $INSTANCE_B_PRIVATE_IP'"
```

## Cleanup

To avoid incurring charges, clean up the resources created in this lab. The order of deletion is important, as some resources depend on others (for example, you can't delete a VPC until you've deleted all resources within it).

```bash
# Terminate EC2 instances - this is our first step in cleanup
aws ec2 terminate-instances --instance-ids $INSTANCE_A_ID $INSTANCE_B_ID

# Wait for instances to terminate completely before proceeding
aws ec2 wait instance-terminated --instance-ids $INSTANCE_A_ID $INSTANCE_B_ID

# Delete the routes we created for the peering connection
aws ec2 delete-route --route-table-id $RT_A_ID --destination-cidr-block 172.16.0.0/16
aws ec2 delete-route --route-table-id $RT_B_ID --destination-cidr-block 10.0.0.0/16

# Delete the VPC peering connection
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PEER_ID

# Delete security groups (we must do this before deleting VPCs)
aws ec2 delete-security-group --group-id $SG_A_ID
aws ec2 delete-security-group --group-id $SG_B_ID

# Delete route tables (note: the main route tables will be deleted when the VPCs are deleted)
aws ec2 delete-route-table --route-table-id $RT_A_ID
aws ec2 delete-route-table --route-table-id $RT_B_ID

# Detach and delete internet gateways (we must detach them before we can delete them)
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_A_ID --vpc-id $VPC_A_ID
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_B_ID --vpc-id $VPC_B_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_A_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_B_ID

# Delete subnets (must be done before deleting VPCs)
aws ec2 delete-subnet --subnet-id $SUBNET_A_ID
aws ec2 delete-subnet --subnet-id $SUBNET_B_ID

# Finally, delete the VPCs themselves
aws ec2 delete-vpc --vpc-id $VPC_A_ID
aws ec2 delete-vpc --vpc-id $VPC_B_ID
```

## Troubleshooting

- If you can't ping between instances, check:
  - Security group rules (ensure inbound ICMP is allowed)
  - Route table configurations
  - VPC peering connection status
  - Instance network ACLs

- If you encounter permission errors, verify your IAM permissions

## Additional Resources

- [AWS VPC Peering Documentation](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)