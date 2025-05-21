provider "aws" {
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "minecraft_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "minecraft-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.minecraft_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "minecraft-public-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.minecraft_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "minecraft-private-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.minecraft_vpc.id

  tags = {
    Name = "minecraft-igw"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.minecraft_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }


  tags = {
    Name = "minecraft-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for Minecraft server
resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft-sg"
  description = "Security group for Minecraft server"
  vpc_id      = aws_vpc.minecraft_vpc.id

  # SSH access from anywhere (for debugging, restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Minecraft server port
  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ServerTap port
  ingress {
    from_port   = 4567
    to_port     = 4567
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "minecraft-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "minecraft_cluster" {
  name = "minecraft-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "minecraft_server" {
  family                   = "minecraft-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024  # 1 vCPU
  memory                   = 2048  # 2GB RAM
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "minecraft-server"
      image     = "itzg/minecraft-server:latest"
      essential = true
      portMappings = [
        {
          containerPort = 25565
          hostPort      = 25565
          protocol      = "tcp"
        },
        {
          containerPort = 4567
          hostPort      = 4567
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "EULA"
          value = "TRUE"
        },
        {
          name  = "MODE"
          value = "survival"
        },
        {
          name  = "MEMORY"
          value = "1G"
        },
        {
          name  = "MOTD"
          value = "welcome class 30!"
        },
        {
          name  = "TYPE"
          value = "PAPER"
        },
        {
          name  = "VERSION"
          value = "1.20.4"
        },
        {
          name  = "ENABLE_COMMAND_BLOCK"
          value = "true"
        },
        {
          name  = "ENABLE_RCON"
          value = "true"
        },
        {
          name  = "RCON_PASSWORD"
          value = "minecraft"  # Change this to a secure password in production
        },
        {
          name  = "PLUGINS_SYNC_UPDATE"
          value = "true"
        },
        {
          name  = "PLUGINS"
          value = "https://github.com/servertap-io/servertap/releases/download/v0.6.1/servertap-0.6.1.jar"
        },
        {
          name  = "SERVER_TAP_ENABLED"
          value = "true"
        },
        {
          name  = "SERVER_TAP_PORT"
          value = "4567"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/minecraft-server"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "minecraft_service" {
  name            = "minecraft-service"
  cluster         = aws_ecs_cluster.minecraft_cluster.id
  task_definition = aws_ecs_task_definition.minecraft_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id  # Using public subnets to get a public IP
    security_groups  = [aws_security_group.minecraft_sg.id]
    assign_public_ip = true  # Enable public IP assignment
  }

  # Allow external changes to the task definition to happen without Terraform conflict
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "minecraft_logs" {
  name              = "/ecs/minecraft-server"
  retention_in_days = 7
}

data "aws_ecs_task_definition" "current" {
  task_definition = aws_ecs_task_definition.minecraft_server.family
}

# Get the public IP using a local script
resource "null_resource" "get_public_ip" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Fetching public IP of the Minecraft server..."
      IP=$(aws ecs describe-tasks \
        --cluster ${aws_ecs_cluster.minecraft_cluster.arn} \
        --tasks $(aws ecs list-tasks \
          --cluster ${aws_ecs_cluster.minecraft_cluster.arn} \
          --service-name ${aws_ecs_service.minecraft_service.name} \
          --output text \
          --query 'taskArns[0]') \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text | \
        xargs -I {} aws ec2 describe-network-interfaces \
          --network-interface-ids {} \
          --query 'NetworkInterfaces[0].Association.PublicIp' \
          --output text 2>/dev/null || echo "IP_NOT_AVAILABLE")
      echo "public_ip=$IP" > public_ip.txt
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [aws_ecs_service.minecraft_service]
}

# Read the public IP from the file
data "local_file" "public_ip" {
  filename   = "${path.module}/public_ip.txt"
  depends_on = [null_resource.get_public_ip]
}

# Output the public IP of the Minecraft server
output "minecraft_server_public_ip" {
  description = "Public IP address of the Minecraft server"
  value       = try(regex("public_ip=([^\n]+)", data.local_file.public_ip.content)[0], "IP_NOT_AVAILABLE_YET")
}

output "minecraft_server_connection" {
  description = "Connection information for the Minecraft server"
  value       = "Minecraft Server: ${try(regex("public_ip=([^\n]+)", data.local_file.public_ip.content)[0], "IP_NOT_AVAILABLE_YET")}:25565"
}

output "servertap_web_interface" {
  description = "ServerTap Web Interface URL"
  value       = "http://${try(regex("public_ip=([^\n]+)", data.local_file.public_ip.content)[0], "IP_NOT_AVAILABLE_YET")}:4567/v1/overview"
}

# Note: To get the actual public IP after deployment, you can use the AWS CLI:
# aws ecs describe-tasks --cluster minecraft-cluster --tasks $(aws ecs list-tasks --cluster minecraft-cluster --service-name minecraft-service --output text --query 'taskArns[0]') --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text
