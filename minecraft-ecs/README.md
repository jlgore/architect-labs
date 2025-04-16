# Minecraft Server on Amazon ECS Lab

This lab demonstrates how to deploy a Minecraft server using Amazon ECS (Elastic Container Service) while adhering to AWS sandbox environment constraints.

## Prerequisites

- AWS account with sandbox access
- AWS CLI configured with appropriate credentials
- Basic understanding of Docker and container services

## Lab Overview

In this lab, you will:
1. Create a VPC with public and private subnets
2. Set up an ECS cluster
3. Create a task definition for Minecraft
4. Configure a service to run the Minecraft server
5. Set up networking and security
6. Test and connect to your Minecraft server

## Step 1: Create VPC and Networking Components

This step creates the networking foundation for our Minecraft server. We'll create:
- A VPC with public and private subnets in two availability zones
- An Internet Gateway for public internet access
- Route tables to control traffic flow

```bash
# Set variables for our networking components
VPC_NAME="minecraft-vpc"
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
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=minecraft-igw}]" \
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
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=minecraft-public-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Public Subnet 1 created with ID: $PUBLIC_SUBNET_1_ID"

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=minecraft-public-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Public Subnet 2 created with ID: $PUBLIC_SUBNET_2_ID"

# Enable auto-assign public IP on public subnets
aws ec2 modify-subnet-attribute \
    --subnet-id $PUBLIC_SUBNET_1_ID \
    --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
    --subnet-id $PUBLIC_SUBNET_2_ID \
    --map-public-ip-on-launch

# Create private subnets
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_1_CIDR \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=minecraft-private-1}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Private Subnet 1 created with ID: $PRIVATE_SUBNET_1_ID"

PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=minecraft-private-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Private Subnet 2 created with ID: $PRIVATE_SUBNET_2_ID"

# Create route tables
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=minecraft-public-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Public Route Table created with ID: $PUBLIC_RT_ID"

PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=minecraft-private-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Private Route Table created with ID: $PRIVATE_RT_ID"

# Add routes to route tables
aws ec2 create-route \
    --route-table-id $PUBLIC_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

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

Security groups act as virtual firewalls. We'll create one for our Minecraft server:

```bash
# Create Minecraft security group
MC_SG_ID=$(aws ec2 create-security-group \
    --group-name minecraft-sg \
    --description "Security group for Minecraft server" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "Minecraft Security Group created with ID: $MC_SG_ID"

# Add inbound rules to Minecraft security group
# Allow Minecraft traffic (port 25565)
aws ec2 authorize-security-group-ingress \
    --group-id $MC_SG_ID \
    --protocol tcp \
    --port 25565 \
    --cidr 0.0.0.0/0
```

## Step 3: Create an EFS File System for Persistent Storage

To maintain our Minecraft world data across container restarts, we'll use Amazon EFS:

```bash
# Create EFS Security Group
EFS_SG_ID=$(aws ec2 create-security-group \
    --group-name minecraft-efs-sg \
    --description "Security group for Minecraft EFS" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "EFS Security Group created with ID: $EFS_SG_ID"

# Allow NFS traffic from Minecraft security group
aws ec2 authorize-security-group-ingress \
    --group-id $EFS_SG_ID \
    --protocol tcp \
    --port 2049 \
    --source-group $MC_SG_ID

# Create EFS File System
EFS_ID=$(aws efs create-file-system \
    --performance-mode generalPurpose \
    --throughput-mode bursting \
    --encrypted \
    --tags Key=Name,Value=minecraft-data \
    --query 'FileSystemId' \
    --output text)
echo "EFS File System created with ID: $EFS_ID"

# Create mount targets in both AZs
for SUBNET_ID in $PUBLIC_SUBNET_1_ID $PUBLIC_SUBNET_2_ID; do
    aws efs create-mount-target \
        --file-system-id $EFS_ID \
        --subnet-id $SUBNET_ID \
        --security-groups $EFS_SG_ID
done

# Wait for EFS to be available
echo "Waiting for EFS to become available..."
sleep 30
```

## Step 4: Create ECS Cluster

Now let's create an ECS cluster to host our Minecraft server:

```bash
# Create ECS cluster
aws ecs create-cluster \
    --cluster-name minecraft-cluster \
    --tags key=Name,value=minecraft-cluster

# Create IAM role for ECS task execution
TASK_EXECUTION_ROLE_NAME="ecsTaskExecutionRole-minecraft"

# Check if the role already exists
ROLE_ARN=$(aws iam get-role --role-name $TASK_EXECUTION_ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    # Create the role
    ROLE_ARN=$(aws iam create-role \
        --role-name $TASK_EXECUTION_ROLE_NAME \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "ecs-tasks.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }' \
        --query 'Role.Arn' \
        --output text)
    
    # Attach required policies
    aws iam attach-role-policy \
        --role-name $TASK_EXECUTION_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    
    aws iam attach-role-policy \
        --role-name $TASK_EXECUTION_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess
fi

echo "Task Execution Role ARN: $ROLE_ARN"
```

## Step 5: Create a Task Definition for Minecraft

Create a task definition that describes how to run the Minecraft container:

```bash
# Create a task definition file
cat > minecraft-task-definition.json << EOF
{
    "family": "minecraft-server",
    "executionRoleArn": "$ROLE_ARN",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "1024",
    "memory": "2048",
    "volumes": [
        {
            "name": "minecraft-data",
            "efsVolumeConfiguration": {
                "fileSystemId": "$EFS_ID",
                "transitEncryption": "ENABLED",
                "authorizationConfig": {
                    "iam": "DISABLED"
                },
                "rootDirectory": "/"
            }
        }
    ],
    "containerDefinitions": [
        {
            "name": "minecraft-server",
            "image": "itzg/minecraft-server:latest",
            "essential": true,
            "environment": [
                {"name": "EULA", "value": "TRUE"},
                {"name": "TYPE", "value": "PAPER"},
                {"name": "MEMORY", "value": "1G"},
                {"name": "DIFFICULTY", "value": "normal"},
                {"name": "ALLOW_NETHER", "value": "true"},
                {"name": "ENABLE_COMMAND_BLOCK", "value": "true"},
                {"name": "SPAWN_PROTECTION", "value": "0"},
                {"name": "MODE", "value": "survival"},
                {"name": "MOTD", "value": "Minecraft Server on AWS ECS"},
                {"name": "OVERRIDE_SERVER_PROPERTIES", "value": "true"},
                {"name": "ENABLE_RCON", "value": "true"},
                {"name": "RCON_PASSWORD", "value": "minecraft"},
                {"name": "RCON_PORT", "value": "25575"}
            ],
            "mountPoints": [
                {
                    "sourceVolume": "minecraft-data",
                    "containerPath": "/data",
                    "readOnly": false
                }
            ],
            "portMappings": [
                {
                    "containerPort": 25565,
                    "hostPort": 25565,
                    "protocol": "tcp"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/minecraft-server",
                    "awslogs-region": "$REGION",
                    "awslogs-stream-prefix": "ecs",
                    "awslogs-create-group": "true"
                }
            }
        }
    ]
}
EOF

# Register the task definition
TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://minecraft-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)
echo "Task Definition registered with ARN: $TASK_DEFINITION_ARN"
```

## Step 6: Create a Service for Minecraft

Now let's create an ECS service to run and maintain our Minecraft server:

```bash
# Create a CloudWatch Logs group for the container logs
aws logs create-log-group --log-group-name /ecs/minecraft-server

# Create ECS service
SERVICE_NAME="minecraft-service"
aws ecs create-service \
    --cluster minecraft-cluster \
    --service-name $SERVICE_NAME \
    --task-definition minecraft-server \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PUBLIC_SUBNET_1_ID,$PUBLIC_SUBNET_2_ID],securityGroups=[$MC_SG_ID],assignPublicIp=ENABLED}" \
    --tags key=Name,value=minecraft-service

# Wait for service to stabilize
echo "Waiting for the ECS service to stabilize..."
aws ecs wait services-stable \
    --cluster minecraft-cluster \
    --services $SERVICE_NAME
```

## Step 7: Get Connection Information

Retrieve the public IP address to connect to your Minecraft server:

```bash
# Get the latest running task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster minecraft-cluster \
    --service-name $SERVICE_NAME \
    --query 'taskArns[0]' \
    --output text)
echo "Task ARN: $TASK_ARN"

# Get the ENI ID of the task
ENI_ID=$(aws ecs describe-tasks \
    --cluster minecraft-cluster \
    --tasks $TASK_ARN \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
echo "ENI ID: $ENI_ID"

# Get the public IP of the task
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $ENI_ID \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)
echo "Minecraft Server is running at: $PUBLIC_IP:25565"
```

## Step 8: Connect to Your Minecraft Server

Now you can connect to your Minecraft server using the Java Edition client:

1. Open your Minecraft Java Edition client
2. Click "Multiplayer"
3. Click "Add Server"
4. Enter a name (e.g., "AWS ECS Minecraft")
5. Server Address: Enter the public IP from Step 7 (e.g., 12.34.56.78:25565)
6. Click "Done"
7. Select your server and click "Join Server"

Note: It may take a few minutes for the Minecraft server to fully initialize after the container starts.

## Step 9: Clean Up Resources

This step removes all resources to avoid ongoing charges:

```bash
# Delete the ECS service
aws ecs update-service \
    --cluster minecraft-cluster \
    --service $SERVICE_NAME \
    --desired-count 0

aws ecs delete-service \
    --cluster minecraft-cluster \
    --service $SERVICE_NAME \
    --force

# Delete the ECS cluster
aws ecs delete-cluster \
    --cluster minecraft-cluster

# Delete the CloudWatch log group
aws logs delete-log-group \
    --log-group-name /ecs/minecraft-server

# Delete EFS mount targets
for MOUNT_TARGET_ID in $(aws efs describe-mount-targets \
    --file-system-id $EFS_ID \
    --query 'MountTargets[*].MountTargetId' \
    --output text); do
    aws efs delete-mount-target --mount-target-id $MOUNT_TARGET_ID
done

# Wait for mount targets to be deleted
echo "Waiting for EFS mount targets to be deleted..."
sleep 30

# Delete EFS file system
aws efs delete-file-system \
    --file-system-id $EFS_ID

# Delete security groups
aws ec2 delete-security-group \
    --group-id $EFS_SG_ID

aws ec2 delete-security-group \
    --group-id $MC_SG_ID

# Detach and delete Internet Gateway
aws ec2 detach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID
aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID

# Delete subnets
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2_ID
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2_ID

# Delete route tables
aws ec2 delete-route-table --route-table-id $PUBLIC_RT_ID
aws ec2 delete-route-table --route-table-id $PRIVATE_RT_ID

# Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID

# Detach IAM policies from the role
aws iam detach-role-policy \
    --role-name $TASK_EXECUTION_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam detach-role-policy \
    --role-name $TASK_EXECUTION_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess

# Delete IAM role
aws iam delete-role \
    --role-name $TASK_EXECUTION_ROLE_NAME
```

## Notes

- **Sandbox Limitations**: This lab uses resources compatible with AWS sandbox environments:
  - Fargate for serverless container deployment (no EC2 instances required)
  - Minimal resource allocation (1 vCPU, 2GB memory)
  - Single Minecraft server instance to conserve resources

- **Cost Optimization**:
  - ECS Fargate: The container will only run when needed
  - EFS: Only used for persistent data storage
  - Consider stopping the ECS service when not actively using the server

- **Performance Considerations**:
  - The provided configuration is suitable for small Minecraft servers (3-5 players)
  - For better performance, you could increase the CPU and memory in the task definition
  - Use a seed with fewer resource-intensive biomes for better performance

- **Security Notes**:
  - This lab opens the Minecraft port (25565) to the public internet
  - For increased security, consider limiting access to specific IP ranges
  - For a production environment, add password protection or a whitelist of players

- **Persistent Data**:
  - All world data and configurations are stored on EFS for persistence
  - EFS ensures your world data survives container restarts
  - Consider implementing backup strategies for important world data 