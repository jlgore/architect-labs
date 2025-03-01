# EC2 and EFS Integration - Terraform Implementation

# Configure AWS provider
provider "aws" {
  region = var.aws_region
}

# Create a unique identifier to avoid name conflicts
resource "random_id" "unique_id" {
  byte_length = 4
}

# Get available AZs in the region
data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}VPC-${random_id.unique_id.hex}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}IGW-${random_id.unique_id.hex}"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}PublicSubnet-${random_id.unique_id.hex}"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}PrivateSubnet-${random_id.unique_id.hex}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}PublicRT-${random_id.unique_id.hex}"
  }
}

# Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}PrivateRT-${random_id.unique_id.hex}"
  }
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg-${random_id.unique_id.hex}"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}EC2-SG-${random_id.unique_id.hex}"
  }
}

# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  name        = "efs-sg-${random_id.unique_id.hex}"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name = "${var.project_name}EFS-SG-${random_id.unique_id.hex}"
  }
}

# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token   = "efs-${random_id.unique_id.hex}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "${var.project_name}-${random_id.unique_id.hex}"
  }

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

# EFS Mount Target in Public Subnet
resource "aws_efs_mount_target" "public" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs_sg.id]
}

# EFS Mount Target in Private Subnet
resource "aws_efs_mount_target" "private" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key Pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "ec2-efs-lab-key-${random_id.unique_id.hex}"
  public_key = file(var.ssh_public_key_path)
  # Note: You need to generate an SSH key pair first and place the public key in the module directory
  # You can use: ssh-keygen -t rsa -b 2048 -f id_rsa -N ""
}

# EC2 Instance
resource "aws_instance" "efs_client" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Wait for EFS mount targets to be available
  depends_on = [
    aws_efs_mount_target.public,
    aws_efs_mount_target.private
  ]

  user_data = <<-EOF
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

    # Mount EFS
    echo "${aws_efs_file_system.main.id}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
    mount -t efs ${aws_efs_file_system.main.id}:/ /mnt/efs

    # Create a test file in EFS
    echo "This is a test file created on $(date)" > /mnt/efs/test-$(hostname).txt

    chown ec2-user:ec2-user /home/ec2-user/instance-info.txt
  EOF

  tags = {
    Name = "${var.project_name}Instance-${random_id.unique_id.hex}"
  }
}

