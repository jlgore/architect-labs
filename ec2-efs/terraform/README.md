# EC2 and EFS Integration Lab Using Terraform

## Overview
This Terraform project creates an AWS environment with a VPC, public and private subnets, an EC2 instance, and an EFS filesystem. It's designed to demonstrate how EC2 and EFS can be integrated within a custom VPC architecture.

## Prerequisites
1. Terraform installed (v0.12 or newer)
2. AWS CLI configured with appropriate credentials
3. SSH key pair for EC2 access

## Project Structure
- `main.tf`: Main Terraform configuration file
- `variables.tf`: Variable definitions
- `outputs.tf`: Outputs configuration
- `terraform.tfvars` (optional): Variable values

## Setup Instructions

### 1. Clone the repository or create project files
Create a new directory for your Terraform project and copy the provided files into it.

### 2. Generate or use an existing SSH key pair
```bash
# Generate a new SSH key pair if you don't have one
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
```

### 3. Create a terraform.tfvars file (optional)
```hcl
aws_region        = "us-east-1"  # Change to your preferred region
project_name      = "EFSLab"
ssh_public_key_path = "~/.ssh/id_rsa.pub"  # Path to your public key
```

### 4. Initialize Terraform
```bash
terraform init
```

### 5. Plan the deployment
```bash
terraform plan
```

### 6. Apply the configuration
```bash
terraform apply
```
When prompted, type `yes` to confirm the deployment.

### 7. Accessing the EC2 instance
After deployment completes, the public IP address of your EC2 instance will be displayed in the outputs. You can SSH into the instance using:

```bash
ssh -i ~/.ssh/id_rsa ec2-user@<EC2_PUBLIC_IP>
```

### 8. Verify EFS is mounted
Once logged into the EC2 instance, verify that EFS is mounted properly:

```bash
df -h | grep efs
ls -la /mnt/efs
```

You should see the test file that was created during instance startup.

### 9. Testing EFS persistence
Create additional files in the EFS mount:

```bash
echo "This is a test file" | sudo tee /mnt/efs/test-file.txt
```

Reboot the instance (from the AWS console or using Terraform) and verify that the files persist after reboot.

## Cleanup
When you're finished with the lab, you can destroy all created resources:

```bash
terraform destroy
```
When prompted, type `yes` to confirm.

## Lab Questions for Students
Same as the original lab:

1. What role does the security group play in connecting EC2 to EFS?
2. Why is port 2049 specifically needed for EFS?
3. What happens to the data on EFS when the EC2 instance is rebooted?
4. What is the advantage of having mount targets in multiple availability zones?
5. How does EFS differ from EBS in terms of use cases and functionality?
6. What would happen if you terminated the EC2 instance without unmounting the EFS filesystem?
7. How could you secure the EFS data to only allow specific EC2 instances to access it?
8. What performance mode did we use for EFS and what are the alternatives?
9. Why might you want EC2 instances in a private subnet to access an EFS filesystem?
10. What are the benefits of using a custom VPC with public and private subnets instead of the default VPC?

## Additional Terraform-related Questions
1. How does Terraform handle dependencies between resources?
2. What is the purpose of the `depends_on` attribute in the EC2 instance resource?
3. How could you modify this Terraform configuration to create multiple EC2 instances?
4. What are the advantages of using Terraform over AWS CLI for infrastructure deployment?
5. How would you modify this Terraform configuration to include AWS CloudWatch monitoring for the EC2 instance?
