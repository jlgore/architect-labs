# Create a new VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=EFSLabVPC-$UNIQUE_ID}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "Created VPC: $VPC_ID"
echo "VPC_ID=$VPC_ID" >> $RESOURCE_FILE

# Enable DNS hostnames and support for the VPC
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}"

# Create an Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=EFSLabIGW-$UNIQUE_ID}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

echo "Created Internet Gateway: $IGW_ID"
echo "IGW_ID=$IGW_ID" >> $RESOURCE_FILE

# Attach the Internet Gateway to the VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

echo "Attached Internet Gateway to VPC"
