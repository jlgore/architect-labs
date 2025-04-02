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

```bash
# Create the first VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPC-A}]'

# Create the second VPC
aws ec2 create-vpc --cidr-block 172.16.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPC-B}]'
```

### 2. Create Subnets in Each VPC

```bash
# Create subnet in VPC-A
aws ec2 create-subnet --vpc-id <VPC-A-ID> --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subnet-A}]'

# Create subnet in VPC-B
aws ec2 create-subnet --vpc-id <VPC-B-ID> --cidr-block 172.16.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subnet-B}]'
```

### 3. Create a VPC Peering Connection

```bash
# Create the peering connection
aws ec2 create-vpc-peering-connection --vpc-id <VPC-A-ID> --peer-vpc-id <VPC-B-ID> --tag-specifications 'ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=VPC-A-to-VPC-B}]'

# Accept the peering connection
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id <PEERING-CONNECTION-ID>
```

### 4. Configure Route Tables

```bash
# Get the route table IDs
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<VPC-A-ID>"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<VPC-B-ID>"

# Add route in VPC-A's route table to VPC-B
aws ec2 create-route --route-table-id <VPC-A-ROUTE-TABLE-ID> --destination-cidr-block 172.16.0.0/16 --vpc-peering-connection-id <PEERING-CONNECTION-ID>

# Add route in VPC-B's route table to VPC-A
aws ec2 create-route --route-table-id <VPC-B-ROUTE-TABLE-ID> --destination-cidr-block 10.0.0.0/16 --vpc-peering-connection-id <PEERING-CONNECTION-ID>
```

### 5. Launch EC2 Instances in Each VPC

```bash
# Launch instance in VPC-A
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --key-name vockey --subnet-id <SUBNET-A-ID> --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-A}]'

# Launch instance in VPC-B
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --key-name vockey --subnet-id <SUBNET-B-ID> --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-B}]'
```

### 6. Test Connectivity

```bash
# Get the private IP addresses of the instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=Instance-A" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text
aws ec2 describe-instances --filters "Name=tag:Name,Values=Instance-B" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text

# SSH into one instance and ping the other
ssh -i labsuser.pem ec2-user@<INSTANCE-A-PUBLIC-IP>
ping <INSTANCE-B-PRIVATE-IP>
```

## Cleanup

To avoid incurring charges, clean up the resources created in this lab:

```bash
# Terminate EC2 instances
aws ec2 terminate-instances --instance-ids <INSTANCE-A-ID> <INSTANCE-B-ID>

# Delete the routes
aws ec2 delete-route --route-table-id <VPC-A-ROUTE-TABLE-ID> --destination-cidr-block 172.16.0.0/16
aws ec2 delete-route --route-table-id <VPC-B-ROUTE-TABLE-ID> --destination-cidr-block 10.0.0.0/16

# Delete the VPC peering connection
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id <PEERING-CONNECTION-ID>

# Delete the subnets
aws ec2 delete-subnet --subnet-id <SUBNET-A-ID>
aws ec2 delete-subnet --subnet-id <SUBNET-B-ID>

# Delete the VPCs
aws ec2 delete-vpc --vpc-id <VPC-A-ID>
aws ec2 delete-vpc --vpc-id <VPC-B-ID>
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