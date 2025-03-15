# Configure AWS provider
provider "aws" {
  region = var.aws_region
}

# Create a unique identifier
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

# Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}PublicSubnet1-${random_id.unique_id.hex}"
  }
}

# Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}PublicSubnet2-${random_id.unique_id.hex}"
  }
}

# Private Subnet 1 (for RDS)
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}PrivateSubnet1-${random_id.unique_id.hex}"
  }
}

# Private Subnet 2 (for RDS)
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}PrivateSubnet2-${random_id.unique_id.hex}"
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

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}PrivateRT-${random_id.unique_id.hex}"
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
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

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg-${random_id.unique_id.hex}"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name = "${var.project_name}RDS-SG-${random_id.unique_id.hex}"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "db-subnet-group-${random_id.unique_id.hex}"
  description = "DB subnet group for RDS"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}DBSubnetGroup-${random_id.unique_id.hex}"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier           = "rds-${random_id.unique_id.hex}"
  engine               = "mysql"
  engine_version       = var.db_engine_version
  instance_class       = "db.t3.micro"
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp2"
  
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  monitoring_interval    = 0
  
  tags = {
    Name = "${var.project_name}RDS-${random_id.unique_id.hex}"
  }
}

# Fetch AMI ID from GitHub
data "http" "ami_id" {
  url = var.ami_url
}

# Key Pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "ec2-rds-lab-key-${random_id.unique_id.hex}"
  public_key = file(var.ssh_public_key_path)
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = trimspace(data.http.ami_id.body)
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y mysql mariadb-server
              
              # Create a test script to verify DB connection
              cat << 'SCRIPT' > /home/ec2-user/test-db-connection.sh
              #!/bin/bash
              mysql -h ${aws_db_instance.main.endpoint} -u ${var.db_username} -p${var.db_password} ${var.db_name} -e "SELECT VERSION();"
              SCRIPT
              
              chmod +x /home/ec2-user/test-db-connection.sh
              chown ec2-user:ec2-user /home/ec2-user/test-db-connection.sh
              EOF

  tags = {
    Name = "${var.project_name}Instance-${random_id.unique_id.hex}"
  }
} 