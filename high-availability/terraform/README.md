# High Availability and Auto Scaling Lab - Terraform Implementation

This Terraform implementation creates a highly available and auto-scaling infrastructure in AWS, replicating the functionality described in the main lab README.

## Prerequisites

- AWS account with sandbox access
- AWS CLI configured with appropriate credentials
- Terraform installed (version 1.0.0 or later)
- Basic understanding of AWS services and Terraform

## Infrastructure Overview

This Terraform configuration creates:
- A VPC with public and private subnets across two availability zones
- An Application Load Balancer (ALB)
- Auto Scaling Group with launch template
- Security groups for ALB and EC2 instances
- NAT Gateway for private subnet internet access
- All necessary routing and networking components

## Deployment Steps

1. Initialize Terraform:
```bash
terraform init
```

2. Review the planned changes:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

4. To test the infrastructure:
   - The ALB DNS name will be output after deployment
   - You can access the web application using the ALB DNS name
   - Monitor the Auto Scaling Group in the AWS Console

5. Clean up resources:
```bash
terraform destroy
```

## Configuration

The infrastructure can be customized by modifying the variables in `variables.tf` or by providing values during `terraform apply`. Key configurable parameters include:

- VPC CIDR block
- Subnet CIDR blocks
- Instance type
- Auto Scaling Group min/max/desired capacity
- Scaling policy thresholds

## Notes

- This implementation uses t3.micro instances to stay within sandbox constraints
- The Auto Scaling Group maintains a minimum of 2 instances
- Scaling is based on CPU utilization with a target of 70%
- All resources are tagged for easy identification
- The infrastructure is spread across two availability zones for high availability

## Outputs

After deployment, Terraform will output:
- ALB DNS name
- VPC ID
- Auto Scaling Group name
- Security group IDs 