#!/bin/bash

# Script to destroy AWS resources provisioned by deploy_insecure_resources.sh
# WARNING: This will permanently delete resources.

echo "Starting resource destruction..."

# Check for resource_prefix.txt
if [ ! -f resource_prefix.txt ]; then
    echo "Error: resource_prefix.txt not found. This file is needed to identify resources to delete."
    echo "Please ensure you are in the cspm-lab directory and the deployment script was run successfully."
    exit 1
fi

source resource_prefix.txt # Loads the PREFIX variable

if [ -z "$PREFIX" ]; then
    echo "Error: PREFIX variable is not set. Exiting."
    exit 1
fi

echo "Using resource prefix: $PREFIX"

# Determine AWS Region
export AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    export AWS_REGION="us-east-1" # Default to us-east-1 if not configured
fi
echo "Using AWS Region: $AWS_REGION"

# --- Helper function to get VPC ID by its Name tag ---
get_vpc_id_by_tag() {
    local vpc_name_tag_value="$1"
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$vpc_name_tag_value" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION"
}

# --- Helper function to get Subnet ID by its Name tag ---
get_subnet_id_by_tag() {
    local subnet_name_tag_value="$1"
    aws ec2 describe-subnets --filters "Name=tag:Name,Values=$subnet_name_tag_value" --query "Subnets[0].SubnetId" --output text --region "$AWS_REGION"
}

# --- Helper function to get Internet Gateway ID by its Name tag ---
get_igw_id_by_tag() {
    local igw_name_tag_value="$1"
    aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=$igw_name_tag_value" --query "InternetGateways[0].InternetGatewayId" --output text --region "$AWS_REGION"
}

# --- Helper function to get Route Table ID by its Name tag ---
get_route_table_id_by_tag() {
    local rt_name_tag_value="$1"
    aws ec2 describe-route-tables --filters "Name=tag:Name,Values=$rt_name_tag_value" --query "RouteTables[0].RouteTableId" --output text --region "$AWS_REGION"
}

# --- Helper function to get Security Group ID by its Name tag (and VPC ID for specificity) ---
get_sg_id_by_tag_and_vpc() {
    local sg_name_tag_value="$1"
    local vpc_id="$2"
    if [ -z "$vpc_id" ] || [ "$vpc_id" == "None" ]; then
        echo "Warning: VPC ID not provided for SG lookup: $sg_name_tag_value"
        aws ec2 describe-security-groups --filters "Name=tag:Name,Values=$sg_name_tag_value" --query "SecurityGroups[0].GroupId" --output text --region "$AWS_REGION"
    else
        aws ec2 describe-security-groups --filters "Name=tag:Name,Values=$sg_name_tag_value" "Name=vpc-id,Values=$vpc_id" --query "SecurityGroups[0].GroupId" --output text --region "$AWS_REGION"
    fi
}

# --- Get common resource IDs ---
VPC_NAME_TAG_VALUE="${PREFIX}-vpc"
VPC_ID=$(get_vpc_id_by_tag "$VPC_NAME_TAG_VALUE")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "VPC with tag Name=$VPC_NAME_TAG_VALUE not found or already deleted. Proceeding with deletion of other resources."
    # Not exiting, as some resources (like S3, RDS not in VPC) might still exist or need cleanup.
fi

# 1. Delete EC2 Instances
echo "Terminating EC2 instances..."
INSTANCE_NAME_TAG_PREFIXES=("${PREFIX}-ssh-instance" "${PREFIX}-rdp-instance" "${PREFIX}-all-open-instance")
ALL_INSTANCE_IDS=()

for name_prefix in "${INSTANCE_NAME_TAG_PREFIXES[@]}"; do
    # Query instances that are not already terminated or in the process of terminating
    instance_ids_found=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$name_prefix" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" --query "Reservations[*].Instances[*].InstanceId" --output text --region "$AWS_REGION")
    for id in $instance_ids_found; do
        ALL_INSTANCE_IDS+=($id)
    done
done

# Remove duplicates just in case
UNIQUE_INSTANCE_IDS=($(echo "${ALL_INSTANCE_IDS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [ ${#UNIQUE_INSTANCE_IDS[@]} -gt 0 ]; then
    echo "Found instance IDs to terminate: ${UNIQUE_INSTANCE_IDS[@]}"
    aws ec2 terminate-instances --instance-ids "${UNIQUE_INSTANCE_IDS[@]}" --region "$AWS_REGION"
    echo "Waiting for instances (${UNIQUE_INSTANCE_IDS[@]}) to terminate..."
    aws ec2 wait instance-terminated --instance-ids "${UNIQUE_INSTANCE_IDS[@]}" --region "$AWS_REGION"
    echo "EC2 instances terminated."
else
    echo "No active EC2 instances found with the specified tags."
fi

# 2. Delete RDS Instance
RDS_INSTANCE_ID="${PREFIX}-insecure-db"
echo "Attempting to delete RDS instance: $RDS_INSTANCE_ID (this may take a while)..."
rds_status=$(aws rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE_ID" --query "DBInstances[0].DBInstanceStatus" --output text --region "$AWS_REGION" 2>/dev/null)

if [ "$rds_status" != "" ] && [ "$rds_status" != "None" ]; then
    aws rds delete-db-instance --db-instance-identifier "$RDS_INSTANCE_ID" --skip-final-snapshot --delete-automated-backups --region "$AWS_REGION"
    echo "Waiting for RDS instance $RDS_INSTANCE_ID to be deleted..."
    aws rds wait db-instance-deleted --db-instance-identifier "$RDS_INSTANCE_ID" --region "$AWS_REGION"
    echo "RDS instance $RDS_INSTANCE_ID deleted."
else
    echo "RDS instance $RDS_INSTANCE_ID not found or already deleted."
fi

# 3. Delete S3 Bucket
PUBLIC_BUCKET_NAME="${PREFIX}-public-bucket"
echo "Attempting to delete S3 bucket: $PUBLIC_BUCKET_NAME..."
if aws s3api head-bucket --bucket "$PUBLIC_BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "Deleting policy for bucket $PUBLIC_BUCKET_NAME..."
    aws s3api delete-bucket-policy --bucket "$PUBLIC_BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null || echo "No policy to delete or error deleting policy for $PUBLIC_BUCKET_NAME."
    echo "Emptying and deleting bucket $PUBLIC_BUCKET_NAME..."
    aws s3 rb "s3://$PUBLIC_BUCKET_NAME" --force --region "$AWS_REGION"
    echo "S3 bucket $PUBLIC_BUCKET_NAME deleted."
else
    echo "S3 bucket $PUBLIC_BUCKET_NAME not found or already deleted."
fi

# 4. Delete DB Subnet Group (after RDS instance is deleted)
DB_SUBNET_GROUP_NAME="${PREFIX}-db-subnet-group"
echo "Attempting to delete DB Subnet Group: $DB_SUBNET_GROUP_NAME..."
db_subnet_group_exists=$(aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" --query "DBSubnetGroups[0].DBSubnetGroupName" --output text --region "$AWS_REGION" 2>/dev/null)
if [ "$db_subnet_group_exists" == "$DB_SUBNET_GROUP_NAME" ]; then
    aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" --region "$AWS_REGION"
    echo "DB Subnet Group $DB_SUBNET_GROUP_NAME deleted."
else
    echo "DB Subnet Group $DB_SUBNET_GROUP_NAME not found or already deleted."
fi

# 5. Delete Security Groups (after EC2 and RDS instances)
SG_NAME_TAG_SUFFIXES=("ssh-open" "rdp-open" "mysql-open" "all-open")
echo "Attempting to delete Security Groups..."
for sg_suffix in "${SG_NAME_TAG_SUFFIXES[@]}"; do
    SG_NAME_TAG_VALUE="${PREFIX}-${sg_suffix}"
    SG_ID=$(get_sg_id_by_tag_and_vpc "$SG_NAME_TAG_VALUE" "$VPC_ID")
    if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
        echo "Deleting Security Group: $SG_NAME_TAG_VALUE (ID: $SG_ID)..."
        aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Successfully initiated deletion of SG $SG_ID ($SG_NAME_TAG_VALUE)."
        else
            echo "Failed to delete SG $SG_ID ($SG_NAME_TAG_VALUE). It might still have dependencies (like ENIs from recently terminated instances), was already deleted, or an error occurred. You may need to check manually."
        fi
    else
        echo "Security Group with tag Name=$SG_NAME_TAG_VALUE not found or already deleted."
    fi
done
echo "Security Groups deletion process attempted."

# 6. Delete VPC Components (only if VPC was found)
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "Starting VPC component deletion for VPC ID: $VPC_ID (Name Tag: $VPC_NAME_TAG_VALUE)"

    # Detach and Delete Internet Gateway
    IGW_NAME_TAG_VALUE="${PREFIX}-igw"
    IGW_ID=$(get_igw_id_by_tag "$IGW_NAME_TAG_VALUE")
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        echo "Detaching Internet Gateway $IGW_ID from VPC $VPC_ID..."
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION"
        echo "Deleting Internet Gateway $IGW_ID..."
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"
    else
        echo "Internet Gateway with tag Name=$IGW_NAME_TAG_VALUE not found in VPC $VPC_ID or already deleted."
    fi

    # Delete Custom Route Table (disassociate first)
    RT_NAME_TAG_VALUE="${PREFIX}-rt"
    ROUTE_TABLE_ID=$(get_route_table_id_by_tag "$RT_NAME_TAG_VALUE")
    if [ "$ROUTE_TABLE_ID" != "None" ] && [ -n "$ROUTE_TABLE_ID" ]; then
        echo "Processing Route Table $ROUTE_TABLE_ID (Tag: $RT_NAME_TAG_VALUE)..."
        ASSOCIATION_IDS=$(aws ec2 describe-route-tables --route-table-ids "$ROUTE_TABLE_ID" --query "RouteTables[0].Associations[?Main!=true].RouteTableAssociationId" --output text --region "$AWS_REGION")
        for assoc_id in $ASSOCIATION_IDS; do
            if [ -n "$assoc_id" ]; then
                echo "Disassociating Route Table Association $assoc_id..."
                aws ec2 disassociate-route-table --association-id "$assoc_id" --region "$AWS_REGION"
            fi
        done
        echo "Deleting Route Table $ROUTE_TABLE_ID..."
        aws ec2 delete-route-table --route-table-id "$ROUTE_TABLE_ID" --region "$AWS_REGION"
    else
        echo "Custom Route Table with tag Name=$RT_NAME_TAG_VALUE not found or already deleted."
    fi

    # Delete Subnets
    SUBNET1_NAME_TAG_VALUE="${PREFIX}-subnet"
    SUBNET1_ID=$(get_subnet_id_by_tag "$SUBNET1_NAME_TAG_VALUE")
    if [ "$SUBNET1_ID" != "None" ] && [ -n "$SUBNET1_ID" ]; then
        echo "Deleting Subnet $SUBNET1_ID (Tag: $SUBNET1_NAME_TAG_VALUE)..."
        aws ec2 delete-subnet --subnet-id "$SUBNET1_ID" --region "$AWS_REGION"
    else
        echo "Subnet with tag Name=$SUBNET1_NAME_TAG_VALUE not found or already deleted."
    fi

    SUBNET2_NAME_TAG_VALUE="${PREFIX}-subnet2"
    SUBNET2_ID=$(get_subnet_id_by_tag "$SUBNET2_NAME_TAG_VALUE")
    if [ "$SUBNET2_ID" != "None" ] && [ -n "$SUBNET2_ID" ]; then
        echo "Deleting Subnet $SUBNET2_ID (Tag: $SUBNET2_NAME_TAG_VALUE)..."
        aws ec2 delete-subnet --subnet-id "$SUBNET2_ID" --region "$AWS_REGION"
    else
        echo "Subnet with tag Name=$SUBNET2_NAME_TAG_VALUE not found or already deleted."
    fi
    
    # Wait for subnets and other resources like ENIs to be fully cleaned up
    echo "Pausing for 60 seconds to allow network interfaces and subnets to be fully released before VPC deletion..."
    sleep 60

    # Delete VPC
    echo "Attempting to delete VPC $VPC_ID (Tag: $VPC_NAME_TAG_VALUE)..."
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$AWS_REGION"
    if [ $? -eq 0 ]; then
        echo "VPC $VPC_ID deletion initiated."
    else
        echo "Failed to delete VPC $VPC_ID. This usually means some dependent resources (e.g. ENIs, security groups, subnets) still exist. Please check the AWS console."
    fi
else
    echo "VPC with tag Name=$VPC_NAME_TAG_VALUE was not found initially, skipping deletion of VPC and its dependent components."
fi

# 7. Clean up local files
echo "Cleaning up local lab files..."
if [ -f resource_prefix.txt ]; then
    rm -f resource_prefix.txt
    echo "Removed resource_prefix.txt"
fi

if [ -d data ]; then
    rm -rf data
    echo "Removed data directory"
fi

echo "Resource destruction script finished."
echo "Please verify in the AWS console that all resources associated with prefix '$PREFIX' have been deleted."
echo "Some resources like Security Groups or the VPC might require manual intervention if dependencies were not automatically cleared." 