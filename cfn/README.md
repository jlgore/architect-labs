# CloudFormation Master Class

## Introduction
CloudFormation is AWS's infrastructure as code (IaC) service that enables you to model, provision, and manage AWS and third-party resources by treating infrastructure as code.

## Table of Contents
1. [Fundamentals](#fundamentals)
2. [Template Structure](#template-structure)
3. [Resource Types](#resource-types)
4. [Parameters, Mappings and Conditions](#parameters-mappings-and-conditions)
5. [Intrinsic Functions](#intrinsic-functions)
6. [Outputs](#outputs)
7. [Nested Stacks](#nested-stacks)
8. [Best Practices](#best-practices)
9. [Examples](#examples)
10. [Deployment Guide](#deployment-guide)

## Fundamentals

### Key Concepts
- **Template**: JSON or YAML formatted text file that describes your AWS infrastructure
- **Stack**: A collection of AWS resources created and managed as a single unit
- **Change Set**: A summary of proposed changes to a stack before executing them

### Benefits
- **Infrastructure as Code**: Manage infrastructure using code files
- **Consistency**: Replicate infrastructure across regions and accounts
- **Version Control**: Track changes with source control systems
- **Cost**: No additional charges for CloudFormation (pay only for deployed resources)

## Template Structure

A CloudFormation template contains the following sections:

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: A sample template
Metadata:
  # Template metadata
Parameters:
  # Input parameters
Mappings:
  # Key-value mappings
Conditions:
  # Conditions for resource creation
Transform:
  # For serverless applications or macros
Resources:
  # AWS resources to create
Outputs:
  # Values to return
```

Only the `Resources` section is required.

## Resource Types

Resources are declared using the following format:

```yaml
Resources:
  LogicalID:
    Type: AWS::Service::Resource
    Properties:
      Property1: Value1
      Property2: Value2
```

Common resource types:
- **EC2**: `AWS::EC2::Instance`, `AWS::EC2::VPC`, `AWS::EC2::SecurityGroup`
- **S3**: `AWS::S3::Bucket`
- **RDS**: `AWS::RDS::DBInstance`
- **IAM**: `AWS::IAM::Role`, `AWS::IAM::Policy`
- **Lambda**: `AWS::Lambda::Function`

## Parameters, Mappings and Conditions

### Parameters
Parameters allow you to input custom values when creating a stack:

```yaml
Parameters:
  InstanceType:
    Type: String
    Default: t2.micro
    AllowedValues:
      - t2.micro
      - t2.small
    Description: EC2 instance type
```

### Mappings
Mappings are fixed key-value pairs for lookup:

```yaml
Mappings:
  RegionMap:
    us-east-1:
      AMI: ami-0ff8a91507f77f867
    us-west-1:
      AMI: ami-0bdb828fd58c52235
```

### Conditions
Conditions determine whether resources are created:

```yaml
Conditions:
  CreateProdResources: !Equals [!Ref Environment, "prod"]
```

## Intrinsic Functions

CloudFormation provides several built-in functions:

- `!Ref` - Returns the value of a parameter or resource
- `!GetAtt` - Returns the value of an attribute from a resource
- `!Join` - Joins values with a delimiter
- `!Sub` - Substitutes variables in a string
- `!If` - Returns one value if a condition is true, another if false
- `!Equals`, `!Not`, `!And`, `!Or` - Condition functions

Example:
```yaml
SecurityGroupIngress:
  - IpProtocol: tcp
    FromPort: 80
    ToPort: 80
    CidrIp: !Ref AllowedCidr
```

## Outputs

Outputs declare values that can be imported into other stacks:

```yaml
Outputs:
  VPCId:
    Description: The ID of the VPC
    Value: !Ref MyVPC
    Export:
      Name: !Sub "${AWS::StackName}-VPC"
```

## Nested Stacks

Nested stacks allow you to reuse common components:

```yaml
Resources:
  NetworkStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3.amazonaws.com/bucket/network.yaml
      Parameters:
        VPCCidr: 10.0.0.0/16
```

## Best Practices

1. **Validate templates** before deployment using `aws cloudformation validate-template`
2. **Use version control** to track template changes
3. **Implement proper IAM permissions** for CloudFormation
4. **Use Parameters** for values that change between environments
5. **Leverage Nested Stacks** for reusable components
6. **Create Change Sets** before updating stacks
7. **Add descriptive comments** in your templates
8. **Use Stack Policies** to prevent accidental updates
9. **Set up CloudWatch Alarms** to monitor stack resources
10. **Implement resource cleanup** to avoid orphaned resources

## Examples

### Basic VPC Template

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Basic VPC Template"

Resources:
  MyVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: MyVPC

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MyVPC
      CidrBlock: 10.0.1.0/24
      MapPublicIpOnLaunch: true
      AvailabilityZone: !Select [0, !GetAZs ""]
      Tags:
        - Key: Name
          Value: Public Subnet

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: MyIGW

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref MyVPC
      InternetGatewayId: !Ref InternetGateway

Outputs:
  VPCId:
    Description: The ID of the VPC
    Value: !Ref MyVPC
    Export:
      Name: !Sub "${AWS::StackName}-VPCID"
```

## Deployment Guide

This section provides step-by-step instructions for deploying and interacting with CloudFormation stacks using the AWS CLI.

### Getting the Templates

Before you begin, download the CloudFormation templates from the GitHub repository:

```bash
# Clone the repository
git clone https://github.com/jlgore/architect-labs.git

# Navigate to the CloudFormation templates directory
cd architect-labs/cfn

# If you don't have git installed, you can download directly using:
# For Linux/Mac
curl -LO https://github.com/jlgore/architect-labs/archive/main.zip
unzip main.zip
cd architect-labs-main/cfn

# For Windows PowerShell
Invoke-WebRequest -Uri https://github.com/jlgore/architect-labs/archive/main.zip -OutFile main.zip
Expand-Archive -Path main.zip -DestinationPath .
cd architect-labs-main/cfn
```

### Prerequisites

1. Install and configure the AWS CLI:
   ```bash
   # Install AWS CLI (if not already installed)
   pip install awscli --upgrade --user
   
   # Configure AWS CLI with your credentials
   aws configure
   ```

2. Ensure your AWS user has the necessary permissions to create and manage CloudFormation stacks and their resources.

### Creating an EC2 Key Pair for SSH Access

Before deploying any stacks that include EC2 instances, you need to create a key pair for SSH access:

```bash
# Create a new key pair
aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > MyKeyPair.pem

# Set the right permissions
chmod 400 MyKeyPair.pem
```

This key pair will be referenced in your CloudFormation templates to allow SSH access to your EC2 instances.

### Template Validation

Always validate your templates before deployment:

```bash
# Validate a local template file
aws cloudformation validate-template --template-body file://web-app-stack.yaml

# Validate a template stored in S3
aws cloudformation validate-template --template-url https://s3.amazonaws.com/bucket-name/web-app-stack.yaml
```

### Deploying the Web Application Stack

Before deploying, check what parameters are required by your template:

```bash
# List all parameters in the template
aws cloudformation get-template-summary \
  --template-body file://web-app-stack.yaml \
  --query "Parameters[].{ParameterKey:ParameterKey,DefaultValue:DefaultValue}" \
  --output table
```

To deploy the web application stack:

```bash
# Deploy with all required parameters
aws cloudformation create-stack \
  --stack-name my-web-app \
  --template-body file://web-app-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=KeyName,ParameterValue=MyKeyPair \
               ParameterKey=DBPassword,ParameterValue=YourSecurePassword123

# Check deployment status
aws cloudformation describe-stacks --stack-name my-web-app --query 'Stacks[0].StackStatus'
```

### Connecting to EC2 Instances for Troubleshooting

The web application deploys EC2 instances in private subnets for security. To connect to these instances, you can use either a bastion host or the EC2 Instance Connect Endpoint.

#### Setting Up SSH Agent for Key Forwarding

To connect to private instances through the bastion host, you need to set up SSH agent forwarding:

```bash
# Start the SSH agent
eval $(ssh-agent -s)

# Add your key to the agent
ssh-add MyKeyPair.pem
```

#### Connecting to the Bastion Host

```bash
# Get the bastion host's public IP
BASTION_IP=$(aws cloudformation describe-stacks --stack-name my-web-app --query "Stacks[0].Outputs[?OutputKey=='BastionHostPublicIP'].OutputValue" --output text)

# Connect with agent forwarding enabled
ssh -A ec2-user@$BASTION_IP
```

#### Connecting to Private Web Server Instances

Once connected to the bastion host, you can SSH to private instances without needing to copy the key:

```bash
# From the bastion, find the private IP of your web servers
aws ec2 describe-instances --filters "Name=tag:Name,Values=dev-WebServer*" --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress]" --output table

# Connect to a web server instance
ssh ec2-user@<private-ip-address>
```

#### Alternative: Using EC2 Instance Connect Endpoint

You can also connect directly from your local machine to private instances using the EC2 Instance Connect Endpoint:

```bash
# Find your instance ID
aws ec2 describe-instances --filters "Name=tag:Name,Values=dev-WebServer*" --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress]" --output table

# Connect directly using the endpoint
aws ec2-instance-connect-endpoint ssh --instance-id i-xxxxxxxxxx --os-user ec2-user
```

### Troubleshooting Web Server Issues

Once connected to a web server, you can troubleshoot issues like 502 Bad Gateway errors:

```bash
# Check if Apache is running
sudo systemctl status httpd

# Check Apache error logs
sudo tail -50 /var/log/httpd/error_log

# Check Apache access logs
sudo tail -50 /var/log/httpd/access_log

# Test the health endpoint locally
curl http://localhost/health.php

# Test database connectivity
curl http://localhost/db-test.php
```

If Apache is not running, you can start it:
```bash
sudo systemctl start httpd
sudo systemctl enable httpd
```

### Deploying a Serverless Stack

For deploying the serverless application:

```bash
# First, create an S3 bucket that you have access to
# Replace 'my-deployment-bucket' with a globally unique bucket name
aws s3 mb s3://my-deployment-bucket-$(aws sts get-caller-identity --query Account --output text)

# Verify you have write permissions to this bucket
echo "test" > test.txt
aws s3 cp test.txt s3://my-deployment-bucket-$(aws sts get-caller-identity --query Account --output text)
rm test.txt

# Package the serverless application (required to upload Lambda code to S3)
# Replace with your actual bucket name
BUCKET_NAME="my-deployment-bucket-$(aws sts get-caller-identity --query Account --output text)"
aws cloudformation package \
  --template-file serverless-app.yaml \
  --s3-bucket $BUCKET_NAME \
  --output-template-file packaged-serverless-app.yaml

# Deploy the packaged serverless application
# Don't forget to include the required DBPassword parameter
aws cloudformation deploy \
  --template-file packaged-serverless-app.yaml \
  --stack-name my-serverless-app \
  --parameter-overrides \
      Environment=dev \
      DBPassword=MySecurePassword123 \
  --capabilities CAPABILITY_IAM
```

### Monitoring Deployment Progress

To check the status of a stack deployment:

```bash
# Get stack status
aws cloudformation describe-stacks --stack-name my-web-app

# List stack resources
aws cloudformation list-stack-resources --stack-name my-web-app

# Get detailed information about a specific resource
aws cloudformation describe-stack-resource \
  --stack-name my-web-app \
  --logical-resource-id VPC
```

### Updating a Stack

To update an existing stack:

```bash
# Update with modified template
aws cloudformation update-stack \
  --stack-name my-web-app \
  --template-body file://web-app-stack-updated.yaml \
  --capabilities CAPABILITY_IAM

# Update with new parameter values
aws cloudformation update-stack \
  --stack-name my-web-app \
  --use-previous-template \
  --parameters ParameterKey=InstanceType,ParameterValue=t3.medium \
  --capabilities CAPABILITY_IAM
```

### Using Change Sets

For a safer update process, use change sets:

```bash
# Create a change set
aws cloudformation create-change-set \
  --stack-name my-web-app \
  --change-set-name web-app-changes \
  --template-body file://web-app-stack-updated.yaml \
  --capabilities CAPABILITY_IAM

# Describe change set to review changes
aws cloudformation describe-change-set \
  --stack-name my-web-app \
  --change-set-name web-app-changes

# Execute change set after review
aws cloudformation execute-change-set \
  --stack-name my-web-app \
  --change-set-name web-app-changes
```

### Getting Stack Outputs

To retrieve output values from a stack:

```bash
# Get all stack outputs
aws cloudformation describe-stacks --stack-name my-web-app --query "Stacks[0].Outputs"

# Get specific output value
aws cloudformation describe-stacks \
  --stack-name my-web-app \
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
  --output text
```

### Working with Stack Resources

After deploying, you may need to interact with the created resources:

```bash
# List instances in the Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(Tags[?Key=='aws:cloudformation:stack-name'].Value, 'my-web-app')]"

# Describe the RDS database instance
aws rds describe-db-instances \
  --query "DBInstances[?TagList[?Key=='aws:cloudformation:stack-name' && Value=='my-web-app']]"

# List objects in the S3 bucket (get bucket name from stack outputs first)
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name my-web-app \
  --query "Stacks[0].Outputs[?OutputKey=='WebAssetsBucketName'].OutputValue" \
  --output text)
aws s3 ls s3://$BUCKET_NAME/
```

### Deleting a Stack

When you're done with your resources, delete the stack:

```bash
# Delete a stack and all its resources
aws cloudformation delete-stack --stack-name my-web-app

# Check deletion status
aws cloudformation describe-stacks --stack-name my-web-app
```

### Troubleshooting

If you encounter issues during deployment:

```bash
# List stack events to find errors
aws cloudformation describe-stack-events \
  --stack-name my-web-app \
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED']"

# List all events in chronological order
aws cloudformation describe-stack-events \
  --stack-name my-web-app \
  --query "sort_by(StackEvents, &Timestamp)"
```

#### Common Issues and Solutions

1. **502 Bad Gateway from ALB**
   - Check if Apache is running on web server instances
   - Verify security groups allow traffic between ALB and EC2 instances
   - Check database connectivity works properly
   - Examine detailed logs in `/var/log/httpd/`

2. **Instance Connect Issues**
   - Make sure the EC2 Instance Connect Endpoint is properly configured
   - Verify security groups allow SSH traffic
   - Check that the instance is running

CloudFormation is a powerful service that simplifies infrastructure management. This guide covers the fundamentals, but AWS documentation provides comprehensive details on all supported resources and features.

### Troubleshooting AWS Academy Sandbox Limitations

When working in the AWS Academy Sandbox environment, you might encounter limitations with certain AWS services. This section provides guidance on common issues:

1. **Service Restrictions**: The sandbox only allows specific services. Refer to the sandbox documentation for the full list of available services.

2. **Permission Errors**: If you see "Access Denied" errors, it's likely that the operation is restricted in the sandbox environment.

3. **Template Simplification**: If your CloudFormation stack fails to deploy, try simplifying it to use only the core services explicitly allowed in the sandbox.