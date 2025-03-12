#!/bin/bash
set -e

# Configuration
PACKER_TEMPLATE="student-ami.pkr.hcl"
AWS_REGION="us-east-1"  # Change to your desired region
AMI_FILE="amiId.txt"

echo "Starting AMI build process..."

# Build the AMI with Packer
echo "Building AMI with Packer..."
PACKER_LOG=1 packer build -color=false $PACKER_TEMPLATE > packer_build.log

# Extract the AMI ID from the Packer output
echo "Extracting AMI ID from build output..."
AMI_ID=$(grep -oP 'ami-[a-z0-9]+' packer_build.log | tail -1)

if [ -z "$AMI_ID" ]; then
    echo "Failed to extract AMI ID from Packer output. Check packer_build.log for details."
    exit 1
fi

echo "Successfully built AMI: $AMI_ID"

# Save the AMI ID to a file
echo "Saving AMI ID to $AMI_FILE..."
echo "$AMI_ID" > "$AMI_FILE"
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - $AMI_ID" >> "ami_history.log"

echo "Process completed successfully!"
echo "AMI ID: $AMI_ID"
echo "AMI ID saved to: $AMI_FILE"
echo ""
echo "Students can access this AMI using the Terraform HTTP provider:"
echo ""
echo "data \"http\" \"ami_id\" {"
echo "  url = \"https://raw.githubusercontent.com/jlgore/architect-labs/main/ami/$AMI_FILE\""
echo "}"
echo ""
echo "resource \"aws_instance\" \"app_server\" {"
echo "  ami = trimspace(data.http.ami_id.body)"
echo "  # other configuration..."
echo "}"