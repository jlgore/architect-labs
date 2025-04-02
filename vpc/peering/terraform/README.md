# VPC Peering with Terraform

This Terraform configuration creates a VPC peering connection between two VPCs in AWS, along with the necessary networking components and EC2 instances to test the connectivity.

## Overview

The configuration creates:
- Two VPCs with different CIDR blocks
- Subnets in each VPC
- Internet gateways for each VPC
- Route tables with routes to the internet and the peered VPC
- Security groups for EC2 instances
- EC2 instances in each VPC to test connectivity

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed (v0.12 or later)
- AWS CLI configured with appropriate credentials
- Access to an AWS account with permissions to create the resources defined in this configuration

## Sandbox Compatibility

This configuration is designed to work within the AWS Academy Cloud Architecting sandbox environment, which has the following restrictions:

- EC2 instance types limited to: t2.nano, t2.micro, t2.small, t2.medium, t3.nano, t3.micro, t3.small, t3.medium
- EBS volumes limited to 35 GB and type General Purpose SSD (gp2)
- On-Demand instances only
- Amazon provided Linux and Windows AMIs only
- Maximum of 9 instances per account

## Usage

1. Clone this repository or download the Terraform files.

2. Navigate to the directory containing the Terraform files:
   ```
   cd vpc/peering/terraform
   ```

3. Initialize Terraform:
   ```
   terraform init
   ```

4. Review the planned changes:
   ```
   terraform plan
   ```

5. Apply the configuration:
   ```
   terraform apply
   ```

6. After the resources are created, you can test the connectivity between the instances using the command provided in the outputs.

7. When you're done, destroy the resources:
   ```
   terraform destroy
   ```

## Customization

You can customize the configuration by modifying the variables in `variables.tf` or by providing values for the variables when running Terraform commands:

```
terraform apply -var="instance_type=t3.micro" -var="vpc_a_cidr=192.168.0.0/16"
```

## Files

- `main.tf`: Main Terraform configuration file
- `variables.tf`: Variable definitions
- `outputs.tf`: Output definitions

## Troubleshooting

- If you encounter permission errors, verify your AWS credentials and permissions.
- If the instances can't communicate, check the security group rules and route tables.
- If you see errors about instance types or AMIs, ensure you're using values compatible with the sandbox environment.

## Additional Resources

- [AWS VPC Peering Documentation](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
