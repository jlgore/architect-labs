provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Generate random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
  # Exclude characters not allowed in RDS passwords: /, @, ", and spaces
  override_special = "!#$%&*()-_=+[{]}\\|;:,<.>?"
}

# Store the password in SSM Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.environment}/quickmart/db/password"
  description = "Password for QuickMart RDS"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "qm-rds-sg"
  description = "Security group for QuickMart RDS database"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere for testing
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name        = "qm-rds-sg"
    Environment = var.environment
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "qm-lambda-sg"
  description = "Security group for QuickMart Lambda functions"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "qm-lambda-sg"
    Environment = var.environment
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "quickmart" {
  name       = "qm-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "qm-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Instance
resource "aws_db_instance" "quickmart" {
  identifier             = "qm-postgres-db"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_storage_size
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.quickmart.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot   = true
  publicly_accessible    = true
  multi_az               = false

  tags = {
    Name        = "qm-postgres-db"
    Environment = var.environment
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "qm-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy for Lambda functions in VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy for accessing RDS
resource "aws_iam_policy" "rds_access" {
  name        = "qm-rds-access-policy"
  description = "Policy for Lambda to access RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db:${aws_db_instance.quickmart.id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.db_password.arn
        ]
      }
    ]
  })
}

# Attach RDS access policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_rds_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.rds_access.arn
}

# Note: Lambda service module definitions have been moved to lambda.tf
# to avoid duplicate module call errors. See lambda.tf for:
# - module "store_service"
# - module "inventory_service" 
# - module "gas_price_service"
