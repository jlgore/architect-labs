# AWS VPC Terraform Lab

This Terraform project creates the same AWS VPC environment as the CLI lab. It provisions a complete VPC setup with public and private subnets, Internet Gateway, route tables, and security groups.

## Prerequisites

- AWS account with appropriate permissions
- [Terraform](https://www.terraform.io/downloads.html) installed (v1.0.0 or later)
- AWS credentials configured (via AWS CLI, environment variables, or .aws/credentials)

## Variables

The following variables can be customized in your own terraform.tfvars file:

| Variable Name | Description | Default Value |
|---------------|-------------|---------------|
| aws_region | AWS region to deploy resources | us-east-1 |
| unique_id | Unique identifier for resource naming | tf |
| vpc_cidr | CIDR block for the VPC | 10.0.0.0/16 |
| public_subnet_cidr | CIDR block for the public subnet | 10.0.1.0/24 |
| private_subnet_cidr | CIDR block for the private subnet | 10.0.2.0/24 |

## Resource Overview

This Terraform configuration creates the following resources:

1. **VPC** with DNS support and hostnames enabled
2. **Subnets**:
   - Public subnet with auto-assign public IP
   - Private subnet
3. **Internet Gateway** attached to the VPC
4. **Route Tables**:
   - Public route table with route to the Internet Gateway
   - Private route table (local routes only)
5. **Security Groups**:
   - Public security group with SSH access from anywhere
   - Private security group with SSH access only from public instances

## Usage

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd vpc/terraform
   ```

2. Create a terraform.tfvars file based on the example:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit the terraform.tfvars file with your preferred values:
   ```bash
   nano terraform.tfvars
   ```

4. Initialize Terraform:
   ```bash
   terraform init
   ```

5. Review the plan:
   ```bash
   terraform plan
   ```

6. Apply the configuration:
   ```bash
   terraform apply
   ```

7. To clean up when you're finished:
   ```bash
   terraform destroy
   ```

## Outputs

After successful deployment, Terraform will output the following resource IDs:

- VPC ID
- Public Subnet ID
- Private Subnet ID
- Internet Gateway ID
- Public Route Table ID
- Private Route Table ID
- Public Security Group ID
- Private Security Group ID

## Customization Examples

### Deploying in a Different AWS Region

```hcl
# In terraform.tfvars
aws_region = "us-west-2"
```

### Creating a VPC with Different CIDR Blocks

```hcl
# In terraform.tfvars
vpc_cidr = "172.16.0.0/16"
public_subnet_cidr = "172.16.1.0/24"
private_subnet_cidr = "172.16.2.0/24"
```

### Adding a Unique Identifier to Resources

```hcl
# In terraform.tfvars
unique_id = "team-a-dev"
```

## Extended Learning

To extend this lab, consider adding:

1. NAT Gateway for internet access from private subnet
2. EC2 instance deployments in public and private subnets
3. VPC Flow Logs for network traffic monitoring
4. S3 VPC Endpoint for private S3 access
5. Additional security group rules for web traffic 