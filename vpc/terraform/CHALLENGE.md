# AWS VPC Advanced Challenge: Multi-Region VPC Peering with Terraform

This challenge extends the basic VPC Terraform lab, guiding you through creating a multi-region VPC architecture with cross-region VPC peering using Infrastructure as Code.

## Challenge Overview

In this challenge, you will:
1. Create VPCs in two different AWS regions using Terraform
2. Deploy EC2 instances in each VPC
3. Establish VPC peering between the two regions
4. Configure route tables to enable cross-VPC communication
5. Test connectivity between instances in different regions

## Prerequisites

- Completed the basic VPC Terraform lab
- [Terraform](https://www.terraform.io/downloads.html) installed (v1.0.0 or later)
- AWS account with access to multiple regions
- AWS credentials configured for CLI access

## Directory Structure

Create the following directory structure for this challenge:

```
vpc-peering-challenge/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

## Implementation Steps

### Step 1: Define Variables

Create a `variables.tf` file to define configuration parameters for your infrastructure. Include variables for regions, CIDR blocks, and instance types.

Minimum requirements:
- Primary and secondary region variables
- CIDR block variables for VPCs and subnets
- EC2 instance type
- Unique identifier for resource naming
- Key pair name variable

### Step 2: Create the VPC Module

Create a reusable VPC module with the following components:
- VPC resource with DNS support enabled
- Public subnet in an availability zone
- Internet Gateway attached to the VPC
- Route table with a route to the Internet Gateway
- Security group allowing SSH and ICMP traffic

<details>
<summary>Looking for additional VPC features to implement?</summary>

```hcl
# In modules/vpc/main.tf, you can add these advanced VPC features:

# Add flow logs for the VPC
resource "aws_flow_log" "vpc_flow_logs" {
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.vpc.id
  
  tags = {
    Name = "FlowLogs-${var.unique_id}-${var.region}"
  }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name = "/aws/vpc/flow-logs-${var.unique_id}-${var.region}"
  retention_in_days = 7
}

# Create a private subnet alongside the public subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)  # e.g., 10.0.2.0/24 if vpc_cidr is 10.0.0.0/16
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet-${var.unique_id}-${var.region}"
  }
}

# Create a NAT Gateway for private subnet internet access
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name = "NAT-EIP-${var.unique_id}-${var.region}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet.id  # Place the NAT Gateway in the public subnet

  tags = {
    Name = "NAT-Gateway-${var.unique_id}-${var.region}"
  }
}

# Create a route table for the private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  # Dynamic block for peering connection - similar to the public route table
  dynamic "route" {
    for_each = var.peering_id != "" ? [1] : []
    content {
      cidr_block                = var.peer_vpc_cidr
      vpc_peering_connection_id = var.peering_id
    }
  }

  tags = {
    Name = "PrivateRT-${var.unique_id}-${var.region}"
  }
}

# Associate private route table with private subnet
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Don't forget to add outputs for these resources!
```
</details>

### Step 3: Create the EC2 Module

Create a reusable EC2 module that:
- Gets the latest Amazon Linux 2 AMI in the specified region
- Launches an EC2 instance with the specified security group
- Allows customization of instance type and key pair

<details>
<summary>Want to enhance your EC2 instances with additional features?</summary>

```hcl
# In modules/ec2/main.tf, you can add these enhancements:

# Add a user data script to configure the instance on launch
resource "aws_instance" "instance" {
  # ... existing configuration ...
  
  user_data = <<-EOF
    #!/bin/bash
    echo "Instance in ${var.region} region" > /home/ec2-user/region_info.txt
    yum update -y
    yum install -y amazon-cloudwatch-agent
    
    # Install some useful tools
    yum install -y jq httpd
    systemctl enable httpd
    systemctl start httpd
    
    # Create a simple web page showing the instance region
    cat > /var/www/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>EC2 Instance Info</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .info { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        </style>
    </head>
    <body>
        <h1>EC2 Instance Information</h1>
        <div class="info">
            <p><strong>Region:</strong> ${var.region}</p>
            <p><strong>Instance ID:</strong> $$(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>Availability Zone:</strong> $$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
            <p><strong>Private IP:</strong> $$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>
            <p><strong>Public IP:</strong> $$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)</p>
        </div>
    </body>
    </html>
    HTML
    
    # Open HTTP port in firewall
    if [ -d /etc/Amazon ]; then
      # Amazon Linux 2
      amazon-linux-extras install -y epel
      yum install -y iptables-services
      iptables -I INPUT -p tcp --dport 80 -j ACCEPT
      service iptables save
    fi
  EOF

  # Add an Elastic IP to ensure the public IP doesn't change
  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

  # Add instance monitoring
  monitoring = true
  
  # Add additional tags
  tags = {
    Name        = "Instance-${var.unique_id}-${var.region}"
    Environment = "Challenge"
    Terraform   = "true"
  }
}

# Create a CloudWatch dashboard to monitor the instance
resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "EC2-Dashboard-${var.unique_id}-${var.region}"
  
  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.instance.id}" ]
        ],
        "period": 60,
        "stat": "Average",
        "region": "${var.region}",
        "title": "CPU Utilization"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "NetworkIn", "InstanceId", "${aws_instance.instance.id}" ],
          [ "AWS/EC2", "NetworkOut", "InstanceId", "${aws_instance.instance.id}" ]
        ],
        "period": 60,
        "stat": "Average",
        "region": "${var.region}",
        "title": "Network Traffic"
      }
    }
  ]
}
EOF
}

# Create an elastic IP address for the instance
resource "aws_eip" "instance_eip" {
  domain = "vpc"
  instance = aws_instance.instance.id
  
  tags = {
    Name = "EIP-${var.unique_id}-${var.region}"
  }
}

# Add these to outputs.tf to expose the new values
output "instance_id" {
  value = aws_instance.instance.id
}

output "public_ip" {
  value = aws_eip.instance_eip.public_ip
}

output "private_ip" {
  value = aws_instance.instance.private_ip
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.ec2_dashboard.dashboard_name}"
}

output "website_url" {
  value = "http://${aws_eip.instance_eip.public_ip}"
}
```
</details>

### Step 4: Create the Main Terraform Files

Set up the main Terraform files to bring together the modules you've created:

1. In `main.tf`:
   - Configure providers for both regions
   - Create VPCs in both regions using your module
   - Set up VPC peering between the regions
   - Configure route tables for cross-VPC communication
   - Launch EC2 instances in both VPCs

2. In `outputs.tf`:
   - Define outputs for resource IDs
   - Include connection instructions for testing

3. In `terraform.tfvars`:
   - Set default values for your variables

<details>
<summary>Need advanced configuration for your Terraform backend and providers?</summary>

```hcl
# Add this to the beginning of main.tf for a more robust configuration

# Configure Terraform backend for state storage
terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_YOUR_BUCKET_NAME"
    key            = "vpc-peering/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Create a DynamoDB table for state locking (you can create this manually first)
# This prevents conflicts when multiple people work on the same Terraform project
resource "aws_dynamodb_table" "terraform_state_lock" {
  provider     = aws.primary
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "TerraformStateLock"
  }
}

# More robust provider configuration with assumed role for cross-account deployments
provider "aws" {
  alias  = "primary"
  region = var.primary_region

  # Uncomment this section if you need to assume a role for cross-account deployment
  # assume_role {
  #   role_arn     = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
  #   session_name = "terraform-vpc-primary"
  # }

  default_tags {
    tags = {
      Project     = "VPC Peering Challenge"
      Environment = "Test"
      Terraform   = "true"
      Region      = var.primary_region
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  
  # Uncomment this section if you need to assume a role for cross-account deployment
  # assume_role {
  #   role_arn     = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
  #   session_name = "terraform-vpc-secondary"
  # }

  default_tags {
    tags = {
      Project     = "VPC Peering Challenge"
      Environment = "Test"
      Terraform   = "true"
      Region      = var.secondary_region
    }
  }
}
```
</details>

<details>
<summary>Want to add cross-region S3 bucket replication?</summary>

```hcl
# Add to main.tf to enable cross-region S3 replication

# Create S3 buckets in each region
resource "aws_s3_bucket" "primary_bucket" {
  provider = aws.primary
  bucket   = "primary-bucket-${var.unique_id}-${random_string.bucket_suffix.result}"

  tags = {
    Name = "PrimaryBucket-${var.unique_id}"
  }
}

resource "aws_s3_bucket" "secondary_bucket" {
  provider = aws.secondary
  bucket   = "secondary-bucket-${var.unique_id}-${random_string.bucket_suffix.result}"

  tags = {
    Name = "SecondaryBucket-${var.unique_id}"
  }
}

# Generate a random suffix for globally unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

# Enable versioning on both buckets (required for replication)
resource "aws_s3_bucket_versioning" "primary_versioning" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "secondary_versioning" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Create IAM role for S3 replication
resource "aws_iam_role" "replication_role" {
  provider = aws.primary
  name     = "s3-replication-role-${var.unique_id}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# Create policy for the replication role
resource "aws_iam_policy" "replication_policy" {
  provider = aws.primary
  name     = "s3-replication-policy-${var.unique_id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.primary_bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.primary_bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.secondary_bucket.arn}/*"
    }
  ]
}
POLICY
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "replication_attachment" {
  provider   = aws.primary
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

# Configure replication
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  provider = aws.primary
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.primary_versioning]
  
  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.primary_bucket.id

  rule {
    id     = "ReplicateAll"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary_bucket.arn
      storage_class = "STANDARD"
    }
  }
}

# Add to outputs.tf to expose bucket information
output "primary_bucket_name" {
  value = aws_s3_bucket.primary_bucket.id
}

output "secondary_bucket_name" {
  value = aws_s3_bucket.secondary_bucket.id
}

output "replication_role_arn" {
  value = aws_iam_role.replication_role.arn
}
```
</details>

## How to Deploy

Once you've created all the necessary files and modules, follow these steps to deploy your infrastructure:

1. Initialize the Terraform configuration:
   ```bash
   terraform init
   ```

2. Validate the configuration:
   ```bash
   terraform validate
   ```

3. Review the execution plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

5. When prompted, type `yes` to confirm the deployment.

<details>
<summary>Want automated Terraform deployment using GitHub Actions?</summary>

Here's a GitHub Actions workflow configuration you can use:

```yaml
# Place this file at .github/workflows/terraform.yml
name: 'Terraform CI/CD'

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
    
    # Use the Bash shell regardless of runner operating system
    defaults:
      run:
        shell: bash
        working-directory: ./vpc-peering-challenge

    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        
    steps:
    - name: Checkout
      uses: actions/checkout@v3

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.3.0

    - name: Terraform Format
      run: terraform fmt -check

    - name: Terraform Init
      run: terraform init

    - name: Terraform Validate
      run: terraform validate

    - name: Terraform Plan
      run: terraform plan -no-color
      if: github.event_name == 'pull_request'

    - name: Terraform Apply
      run: terraform apply -auto-approve
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

To use this:
1. Create a GitHub repository for your Terraform code
2. Add AWS credentials as repository secrets (AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY)
3. Place this file in `.github/workflows/terraform.yml`
4. Push your Terraform code to the repository

Now any push to main will automatically apply your Terraform changes, and pull requests will show plans without applying.
</details>

## Testing Connectivity

After successful deployment, follow these steps to test connectivity between instances:

1. SSH into the primary instance:
   ```bash
   ssh -i your-key.pem ec2-user@<primary_instance_public_ip>
   ```

2. From the primary instance, ping the secondary instance:
   ```bash
   ping <secondary_instance_private_ip>
   ```

3. SSH into the secondary instance:
   ```bash
   ssh -i your-key.pem ec2-user@<secondary_instance_public_ip>
   ```

4. From the secondary instance, ping the primary instance:
   ```bash
   ping <primary_instance_private_ip>
   ```

<details>
<summary>Want to test connectivity using AWS Systems Manager instead of SSH?</summary>

AWS Systems Manager Session Manager lets you connect to your instances without requiring SSH keys or public IP addresses. Here's how to set it up:

```hcl
# Add this to your EC2 module to configure Systems Manager

# Create IAM role for EC2 instances
resource "aws_iam_role" "ssm_role" {
  name = "ssm-role-${var.unique_id}-${var.region}"
  
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach AmazonSSMManagedInstanceCore policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile-${var.unique_id}-${var.region}"
  role = aws_iam_role.ssm_role.name
}

# Update the EC2 instance to use the instance profile
resource "aws_instance" "instance" {
  # ... existing configuration ...
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  
  # Make sure the security group allows outbound HTTPS traffic for SSM
  # This is typically covered by default outbound rules
}
```

After deploying, you can connect to your instances via the AWS Console:
1. Navigate to the EC2 console
2. Select the instance
3. Click "Connect"
4. Choose the "Session Manager" tab
5. Click "Connect"

Or, using the AWS CLI:
```bash
aws ssm start-session --target INSTANCE_ID --region REGION
```

This method is more secure as you don't need to:
- Expose SSH ports in security groups
- Manage SSH key pairs
- Assign public IP addresses
</details>

## Challenge Extensions

After completing the basic challenge, try these extensions:

1. **Add NAT Gateways**:
   - Modify the VPC module to create private subnets
   - Add NAT Gateways in each region
   - Deploy instances in private subnets that can still communicate across regions

2. **Implement a Bastion Host**:
   - Create a public-facing bastion host in each VPC
   - Move the main instances to private subnets
   - Configure security groups for secure access through the bastion hosts

3. **Deploy Region-Specific Services**:
   - Create an S3 bucket in each region
   - Configure instances to access their local S3 bucket
   - Implement cross-region S3 replication

4. **Replace VPC Peering with Transit Gateway**:
   - Create an AWS Transit Gateway
   - Attach both VPCs to the Transit Gateway
   - Update route tables to use the Transit Gateway

5. **Set Up CloudWatch Monitoring**:
   - Create CloudWatch Alarms to monitor network traffic
   - Implement a simple Lambda function to send alerts on network issues

<details>
<summary>Want to implement AWS Transit Gateway instead of VPC Peering?</summary>

```hcl
# Add this to main.tf instead of the VPC peering configuration

# Create a Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  provider = aws.primary
  description = "Transit Gateway for multi-region VPC connectivity"
  
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  
  tags = {
    Name = "TGW-${var.unique_id}"
  }
}

# Create Transit Gateway attachment for the primary VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "primary_attachment" {
  provider = aws.primary
  subnet_ids         = [module.primary_vpc.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.primary_vpc.vpc_id
  
  tags = {
    Name = "TGW-Attachment-Primary-${var.unique_id}"
  }
}

# Share Transit Gateway with the secondary region account
# Note: for cross-account sharing, you would use AWS RAM
# For cross-region in the same account, we need to create a new TGW resource
resource "aws_ec2_transit_gateway" "tgw_secondary" {
  provider = aws.secondary
  description = "Transit Gateway for multi-region VPC connectivity (secondary region)"
  
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  
  tags = {
    Name = "TGW-${var.unique_id}-Secondary"
  }
}

# Create Transit Gateway attachment for the secondary VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "secondary_attachment" {
  provider = aws.secondary
  subnet_ids         = [module.secondary_vpc.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw_secondary.id
  vpc_id             = module.secondary_vpc.vpc_id
  
  tags = {
    Name = "TGW-Attachment-Secondary-${var.unique_id}"
  }
}

# Create Transit Gateway peering between the two regions
resource "aws_ec2_transit_gateway_peering_attachment" "tgw_peering" {
  provider = aws.primary
  peer_account_id         = data.aws_caller_identity.current.account_id
  peer_region             = var.secondary_region
  peer_transit_gateway_id = aws_ec2_transit_gateway.tgw_secondary.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw.id
  
  tags = {
    Name = "TGW-Peering-${var.unique_id}"
  }
}

# Get current account ID
data "aws_caller_identity" "current" {}

# Accept the peering attachment in the secondary region
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "tgw_peering_accepter" {
  provider = aws.secondary
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id
  
  tags = {
    Name = "TGW-Peering-Accepter-${var.unique_id}"
  }
}

# Create Transit Gateway route table in primary region
resource "aws_ec2_transit_gateway_route_table" "primary_rt" {
  provider = aws.primary
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  
  tags = {
    Name = "TGW-RT-Primary-${var.unique_id}"
  }
}

# Create Transit Gateway route table in secondary region
resource "aws_ec2_transit_gateway_route_table" "secondary_rt" {
  provider = aws.secondary
  transit_gateway_id = aws_ec2_transit_gateway.tgw_secondary.id
  
  tags = {
    Name = "TGW-RT-Secondary-${var.unique_id}"
  }
}

# Add route to the secondary VPC CIDR via the TGW peering connection
resource "aws_ec2_transit_gateway_route" "primary_to_secondary" {
  provider = aws.primary
  destination_cidr_block         = var.secondary_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary_rt.id
}

# Add route to the primary VPC CIDR via the TGW peering connection
resource "aws_ec2_transit_gateway_route" "secondary_to_primary" {
  provider = aws.secondary
  destination_cidr_block         = var.primary_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary_rt.id
}

# Associate the primary VPC attachment with the primary TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "primary_association" {
  provider = aws.primary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.primary_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary_rt.id
}

# Associate the secondary VPC attachment with the secondary TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "secondary_association" {
  provider = aws.secondary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secondary_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary_rt.id
}

# Update the VPC route tables to route through Transit Gateway
resource "aws_route" "primary_to_tgw" {
  provider               = aws.primary
  route_table_id         = module.primary_vpc.route_table_id
  destination_cidr_block = var.secondary_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "secondary_to_tgw" {
  provider               = aws.secondary
  route_table_id         = module.secondary_vpc.route_table_id
  destination_cidr_block = var.primary_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw_secondary.id
}
```

Transit Gateway provides several advantages over VPC peering:
1. It acts as a hub that enables thousands of VPCs to connect to each other
2. It simplifies network architecture - one connection per VPC instead of mesh connections
3. It supports transitive routing (A can talk to C through B with a single configuration)
4. It integrates with Direct Connect and VPN connections
5. It scales better for large, complex networks

However, it does come with additional cost compared to VPC peering.
</details>

## Cleanup

When you're done with the challenge, don't forget to clean up your resources to avoid unnecessary charges.

```bash
terraform destroy
```

When prompted, type `yes` to confirm the deletion of all resources.

<details>
<summary>Want to automate cleanup with a scheduled Terraform destroy?</summary>

You can add this scheduled destroy action to your GitHub Actions workflow to automatically clean up resources after a set period:

```yaml
# Add to .github/workflows/terraform-cleanup.yml
name: 'Terraform Auto-Cleanup'

on:
  schedule:
    # Run at 00:00 UTC every Saturday
    - cron: '0 0 * * 6'
  workflow_dispatch:
    # Allow manual triggering

jobs:
  terraform-cleanup:
    name: 'Terraform Cleanup'
    runs-on: ubuntu-latest
    
    defaults:
      run:
        shell: bash
        working-directory: ./vpc-peering-challenge

    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        
    steps:
    - name: Checkout
      uses: actions/checkout@v3

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.3.0

    - name: Terraform Init
      run: terraform init

    - name: Terraform Destroy
      run: terraform destroy -auto-approve
```

This will automatically destroy your infrastructure every Saturday, or you can manually trigger the workflow when needed. This is especially useful for learning environments where you don't want to leave resources running for extended periods.
</details>

## Troubleshooting Tips

- **Module Missing Error**: Ensure all module directories and files are correctly created.
- **Provider Configuration**: Make sure you're using the correct provider aliases in resource declarations.
- **VPC Peering Connection**: If the peering connection isn't being established, check that:
  - The CIDR blocks don't overlap
  - Both VPCs have DNS hostname resolution enabled
  - You have the necessary permissions in both regions
- **Route Tables**: Verify that routes for the peer VPC CIDR are correctly added to both route tables.
- **Security Groups**: Ensure security groups allow ICMP traffic between the VPC CIDR blocks.
- **Key Pair**: Make sure your key pair exists in both regions before deploying.

<details>
<summary>Common Issues and Solutions Cheatsheet</summary>

| Problem | Possible Causes | Solution |
|---------|----------------|----------|
| `Error: No valid credential sources found` | AWS credentials not configured | Configure AWS credentials with `aws configure` or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables |
| `Error: Error creating VPC Peering Connection` | Insufficient permissions | Check IAM permissions for EC2 and VPC actions |
| `Error: Error launching source instance: InvalidKeyPair.NotFound` | Key pair not found in the region | Create the key pair in both regions before running Terraform |
| `Error: module not found` | Incorrect module path | Check that module directory structure matches the source path in module block |
| `Error: Error pinging EC2 instance` | Security groups not allowing ICMP | Verify security group rules allow ICMP traffic between the VPC CIDR blocks |
| `Error: Missing required argument` | Required variable not set | Ensure all required variables are defined in terraform.tfvars or with -var flag |
| `Error: Error accepting VPC peering connection` | Peering connection not created properly | Check that peering connection was created successfully and that you have permissions to accept it |
| `Error: Peer address CIDR conflicts with the route's own CIDR` | Overlapping CIDR blocks | Make sure the CIDR blocks for the VPCs don't overlap |
| `Error: operation error EC2: DescribeRouteTables` | Insufficient permissions | Check IAM permissions for EC2 and route table actions |
| `Error: provider.aws: no suitable configuration found` | Provider not properly configured | Ensure providers are correctly configured with proper aliases and regions |

**Debugging Steps:**
1. Check Terraform logs with TF_LOG=DEBUG terraform apply
2. Verify AWS credentials and permissions
3. Check security group configurations
4. Verify route table entries
5. Confirm VPC CIDR blocks don't overlap
6. Check network ACLs
7. Verify EC2 instances are in 'running' state
8. Try connecting to instances via AWS Console for troubleshooting
9. Check that key pairs exist in both regions
</details> 