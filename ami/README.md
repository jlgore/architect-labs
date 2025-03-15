# Custom AMI for Labs

This directory contains scripts and resources for building and using custom AMIs for lab environments.

## AMI ID

The latest AMI ID is stored in the `amiId.txt` file in this directory. This file is automatically updated by the build script whenever a new AMI is created.

## Using the AMI

### Via Curl

You can fetch the latest AMI ID using curl:

```bash
# Get the latest AMI ID
AMI_ID=$(curl -s https://raw.githubusercontent.com/jlgore/architect-labs/refs/heads/main/ami/amiId.txt)
echo "Latest AMI ID: $AMI_ID"
```

### Creating a Key Pair

Before launching an instance, you'll need a key pair to SSH into it:

```bash
# Create a key pair
KEY_NAME="lab-key-$(date +%Y%m%d)"
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --query 'KeyMaterial' \
  --output text > ${KEY_NAME}.pem

# Set proper permissions for the private key
chmod 400 ${KEY_NAME}.pem

echo "Created key pair: $KEY_NAME"
```

### Launch an EC2 Instance with AWS CLI

Once you have the AMI ID and key pair, you can launch an EC2 instance using the AWS CLI:

```bash
# Set your variables
AMI_ID=$(curl -s https://raw.githubusercontent.com/jlgore/architect-labs/refs/heads/main/ami/amiId.txt)
INSTANCE_TYPE="t2.micro"
KEY_NAME="your-key-pair-name"  # Replace with your key pair name
SECURITY_GROUP_ID="sg-xxxxxxxxxxxxxxxxx"  # Replace with your security group ID
SUBNET_ID="subnet-xxxxxxxxxxxxxxxxx"  # Replace with your subnet ID

# Launch the instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Lab-Instance}]" \
  --count 1

# To get the public IP of your instance (after it's running)
# Replace INSTANCE_ID with the ID of the instance you just created
# aws ec2 describe-instances --instance-ids INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

### Using with Terraform

You can use this AMI in your Terraform configurations with the HTTP provider:

```hcl
data "http" "ami_id" {
  url = "https://raw.githubusercontent.com/jlgore/architect-labs/refs/heads/main/ami/amiId.txt"
}

resource "aws_instance" "app_server" {
  ami           = trimspace(data.http.ami_id.body)
  instance_type = "t2.micro"
  # other configuration...
}
```

## Build Process

The AMI is built using Packer with the configuration in `student-ami.pkr.hcl`. The build process is automated by the `build.sh` script, which:

1. Builds the AMI using Packer
2. Extracts the AMI ID from the build output
3. Updates the `amiId.txt` file with the new AMI ID

To build a new AMI, run:

```bash
./build.sh
```
