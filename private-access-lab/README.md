# Private Access Patterns Lab

This lab teaches a core Solutions Architect pattern: keep workloads private, remove unnecessary public exposure, and use private AWS connectivity wherever possible.

The main building blocks are:

- private subnets
- gateway VPC endpoints for S3 and DynamoDB
- security groups that avoid broad internet exposure
- optional Session Manager access to a private EC2 instance

The lab is designed to show how architects reduce attack surface without immediately reaching for a bastion host or public IP.

## Learning Objectives

By the end of this lab, you should be able to:

- Explain why private subnets are preferred for many workloads
- Create gateway endpoints for S3 and DynamoDB
- Route AWS service traffic privately without using the public internet
- Compare bastion hosts, NAT gateways, and Session Manager access patterns
- Understand when interface endpoints are worth the cost
- Apply least-privilege network design to internal workloads

## Scenario

You are designing the backend environment for `Pixel Pets Backoffice`, an internal application that should not be exposed directly to the internet.

The application needs to:

- read product assets from S3
- write lightweight metadata to DynamoDB
- allow operators to reach an instance only for troubleshooting

Your goals are:

- no public IP on the application instance
- no inbound SSH from the internet
- private access to AWS services where practical

## Why This Lab Matters

This is one of the most common real-world architecture improvements teams make:

- remove public IPs from workloads
- stop using bastions by default
- avoid paying for NAT when gateway endpoints solve the actual requirement
- lock service access down to VPC paths where possible

## Cost

This lab has two levels:

### Cheap core path

- VPC, subnet, route tables
- S3 gateway endpoint
- DynamoDB gateway endpoint

This part is effectively very low cost.

### Optional verification path

- one private EC2 instance
- three interface endpoints for Systems Manager access:
  - `ssm`
  - `ssmmessages`
  - `ec2messages`

Those interface endpoints have hourly cost, so keep the optional section short and delete it when done.

## Architecture

Base design:

- one VPC
- one private application subnet
- no public IPs on the workload
- route table without a default internet route
- gateway endpoints for S3 and DynamoDB

Optional operator access design:

- private EC2 instance
- IAM instance role for Session Manager
- interface endpoints for SSM traffic
- no inbound port 22 rule at all

## Prerequisites

- AWS CLI configured with permissions for EC2, IAM, S3, DynamoDB, and optionally Systems Manager/VPC endpoints
- `jq` installed
- optional: Session Manager plugin if you want to use the SSM connection workflow locally

## Lab Overview

1. Create a VPC and private subnet
2. Create a route table with no internet route
3. Create S3 and DynamoDB gateway endpoints
4. Create sample S3 and DynamoDB resources
5. Review how private routing works
6. Optionally add a private EC2 instance and Session Manager access
7. Compare this design with NAT and bastion alternatives
8. Clean up

## Step 1: Set Variables

```bash
LAB_ID=$(date +%Y%m%d%H%M%S)
AWS_REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

VPC_NAME="pixel-pets-private-vpc-${LAB_ID}"
PRIVATE_SUBNET_NAME="pixel-pets-private-subnet-${LAB_ID}"
PRIVATE_RT_NAME="pixel-pets-private-rt-${LAB_ID}"
S3_BUCKET="pixel-pets-private-assets-${ACCOUNT_ID}-${LAB_ID}"
DDB_TABLE="PixelPetsPrivateMeta-${LAB_ID}"

echo "Using region: $AWS_REGION"
echo "Bucket: $S3_BUCKET"
echo "Table: $DDB_TABLE"
```

## Step 2: Create the VPC and Private Subnet

```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.42.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}}]" \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support '{"Value":true}'

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value":true}'

PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.42.1.0/24 \
  --availability-zone "${AWS_REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PRIVATE_SUBNET_NAME}}]" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "VPC ID: $VPC_ID"
echo "Private subnet ID: $PRIVATE_SUBNET_ID"
```

Important detail:

- the subnet is private because we do not attach a route to an internet gateway and we do not assign public IPs

## Step 3: Create a Private Route Table

```bash
PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PRIVATE_RT_NAME}}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 associate-route-table \
  --route-table-id "$PRIVATE_RT_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID"
```

This route table deliberately has no `0.0.0.0/0` route.

That means:

- no direct internet egress
- no NAT usage
- no hidden dependency on public routing

## Step 4: Create Gateway Endpoints for S3 and DynamoDB

Gateway endpoints are usually the cheapest way to give private workloads access to S3 and DynamoDB.

### S3 gateway endpoint

```bash
S3_ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
  --vpc-id "$VPC_ID" \
  --service-name "com.amazonaws.${AWS_REGION}.s3" \
  --vpc-endpoint-type Gateway \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text)
```

### DynamoDB gateway endpoint

```bash
DDB_ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
  --vpc-id "$VPC_ID" \
  --service-name "com.amazonaws.${AWS_REGION}.dynamodb" \
  --vpc-endpoint-type Gateway \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text)
```

Check the route table after creating the endpoints:

```bash
aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query 'RouteTables[0].Routes' \
  --output table
```

What you should see:

- route entries managed by the endpoints for S3 and DynamoDB
- still no general internet route

## Step 5: Create Sample S3 and DynamoDB Resources

### S3 bucket

```bash
if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION"
else
  aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

printf 'private asset manifest\n' > private-asset.txt
aws s3 cp private-asset.txt "s3://${S3_BUCKET}/assets/private-asset.txt"
```

### DynamoDB table

```bash
aws dynamodb create-table \
  --table-name "$DDB_TABLE" \
  --attribute-definitions AttributeName=pk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

aws dynamodb wait table-exists --table-name "$DDB_TABLE"

aws dynamodb put-item \
  --table-name "$DDB_TABLE" \
  --item '{"pk":{"S":"pet#corgi"},"tier":{"S":"rare"},"status":{"S":"active"}}'
```

## Step 6: Restrict S3 Access to the VPC Endpoint

This bucket policy allows reads only when traffic comes through your S3 gateway endpoint.

```bash
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadFromSpecificVpce",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*",
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": "${S3_ENDPOINT_ID}"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$S3_BUCKET" \
  --policy file://bucket-policy.json
```

Architecture takeaway:

- this does not just say who can read
- it says where the read must come from
- that is a strong private-access pattern for internal data

## Step 7: Optional Private EC2 + Session Manager Verification

This section is optional because it introduces small hourly costs for interface endpoints and EC2.

If you want real hands-on verification from inside the private subnet, use this section.

### 7.1 Create security groups with no inbound SSH

```bash
INSTANCE_SG_ID=$(aws ec2 create-security-group \
  --group-name "pixel-pets-private-instance-${LAB_ID}" \
  --description "Private instance security group" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)

ENDPOINT_SG_ID=$(aws ec2 create-security-group \
  --group-name "pixel-pets-endpoints-${LAB_ID}" \
  --description "Security group for interface endpoints" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$ENDPOINT_SG_ID" \
  --protocol tcp \
  --port 443 \
  --cidr 10.42.1.0/24
```

Notice what you are not doing:

- no inbound `22/tcp`
- no `0.0.0.0/0` admin access rule
- the interface endpoints allow only private-subnet HTTPS traffic

### 7.2 Create the IAM role for Session Manager

```bash
cat > ssm-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

ROLE_NAME="pixel-pets-ssm-role-${LAB_ID}"
PROFILE_NAME="pixel-pets-ssm-profile-${LAB_ID}"

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://ssm-trust-policy.json

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME"
```

### 7.3 Create the interface endpoints for SSM

Session Manager for a private instance usually needs these interface endpoints when there is no NAT path:

```bash
for service in ssm ssmmessages ec2messages; do
  aws ec2 create-vpc-endpoint \
    --vpc-id "$VPC_ID" \
    --service-name "com.amazonaws.${AWS_REGION}.${service}" \
    --vpc-endpoint-type Interface \
    --subnet-ids "$PRIVATE_SUBNET_ID" \
    --security-group-ids "$ENDPOINT_SG_ID" \
    --private-dns-enabled
done
```

### 7.4 Launch a private EC2 instance

```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --iam-instance-profile Name="$PROFILE_NAME" \
  --subnet-id "$PRIVATE_SUBNET_ID" \
  --security-group-ids "$INSTANCE_SG_ID" \
  --associate-public-ip-address false \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=pixel-pets-private-instance-${LAB_ID}}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
```

### 7.5 Connect using Session Manager

Wait a few minutes for the instance to register with Systems Manager, then connect:

```bash
aws ssm start-session --target "$INSTANCE_ID"
```

Inside the instance, you can test private service access using the instance role:

```bash
aws s3 cp "s3://${S3_BUCKET}/assets/private-asset.txt" -
aws dynamodb get-item --table-name "$DDB_TABLE" --key '{"pk":{"S":"pet#corgi"}}'
```

This is the key teaching moment:

- the instance has no public IP
- there is no SSH ingress
- access to AWS services happens privately through endpoints and instance credentials

## NAT vs Endpoints vs Bastions

Here is the architect tradeoff:

### Bastion host

- simple conceptually
- adds internet-facing admin surface area
- requires SSH key handling and patching
- often overused

### NAT gateway

- useful when private workloads need broad outbound internet access
- simpler than many separate interface endpoints in some cases
- can be more expensive than needed for service-specific access

### Gateway endpoints

- very cost-effective for S3 and DynamoDB
- private path to the service
- best choice when those are the primary dependencies

### Session Manager with interface endpoints

- removes SSH exposure
- gives auditable operator access
- good security posture
- interface endpoints add some hourly cost

## What You Should Observe

- private subnets do not need public IPs to use certain AWS services
- S3 and DynamoDB gateway endpoints remove the need for NAT in many designs
- service access can be restricted to VPC paths, not just IAM principals
- Session Manager is usually cleaner and safer than SSH bastions for administration

## Design Takeaways

1. Keep workloads private by default when they do not need internet exposure.
2. Use gateway endpoints for S3 and DynamoDB before paying for NAT just to reach those services.
3. Prefer Session Manager over SSH for operator access when feasible.
4. Use resource policies that restrict access paths, not just identities.
5. Make public internet access an explicit design choice, not a default habit.

## Fun Extensions

1. Add an interface endpoint for Secrets Manager and compare it with gateway endpoints.
2. Add a second private subnet in another AZ.
3. Restrict DynamoDB access further with an endpoint policy.
4. Add CloudWatch agent traffic and decide whether NAT or more endpoints makes sense.
5. Compare monthly cost of a NAT-heavy design vs targeted endpoints for a small internal app.

## Cleanup

Delete optional resources first if you created them.

### Optional EC2 and SSM cleanup

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
```

If you created interface endpoints, list them and delete them:

```bash
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=${VPC_ID}"
```

Delete each optional interface endpoint returned.

Then delete the optional security groups:

```bash
aws ec2 delete-security-group --group-id "$INSTANCE_SG_ID"
aws ec2 delete-security-group --group-id "$ENDPOINT_SG_ID"
```

If you created the instance profile and role:

```bash
aws iam remove-role-from-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME"

aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME"

aws iam detach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam delete-role --role-name "$ROLE_NAME"
```

### Core resource cleanup

```bash
aws s3 rm "s3://${S3_BUCKET}" --recursive
aws s3api delete-bucket-policy --bucket "$S3_BUCKET"
aws s3api delete-bucket --bucket "$S3_BUCKET"

aws dynamodb delete-table --table-name "$DDB_TABLE"

aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$S3_ENDPOINT_ID" "$DDB_ENDPOINT_ID"

aws ec2 delete-route-table --route-table-id "$PRIVATE_RT_ID"
aws ec2 delete-subnet --subnet-id "$PRIVATE_SUBNET_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID"
```

Delete local files:

```bash
rm -f private-asset.txt bucket-policy.json ssm-trust-policy.json
```
