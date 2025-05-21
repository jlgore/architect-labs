# Minecraft Server on Amazon ECS - Terraform

This Terraform configuration deploys a Minecraft server on AWS ECS Fargate. The setup includes:

- VPC with public and private subnets across two availability zones
- Internet Gateway for public internet access
- Security groups for the Minecraft server
- ECS Fargate cluster and task definition
- CloudWatch Logs for container logging

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (>= 1.0.0)
- Sufficient AWS permissions to create the required resources

## Usage

1. Copy the example variables file and update with your values:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the execution plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

5. After applying, the output will show the DNS name to connect to your Minecraft server.

## Variables

- `aws_region`: AWS region to deploy resources (default: "us-east-1")
- `vpc_cidr`: CIDR block for the VPC (default: "10.0.0.0/16")
- `environment`: Environment name for tagging (default: "dev")

## Outputs

- `vpc_id`: ID of the created VPC
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `security_group_id`: ID of the security group for the Minecraft server
- `ecs_cluster_name`: Name of the ECS cluster
- `ecs_service_name`: Name of the ECS service
- `minecraft_server_dns`: DNS name to connect to the Minecraft server

## Cleaning Up

To destroy all created resources:

```bash
terraform destroy
```

## Notes

- The Minecraft server runs in a single container on Fargate
- The server data is ephemeral by default (stored in the container's filesystem)
- For production use, consider adding persistent storage (EFS) for world data
- The server is configured with 1 vCPU and 2GB of memory, which is suitable for a small number of players
