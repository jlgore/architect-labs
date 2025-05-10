# DuckDB Cloud Security Posture Management (CSPM) Lab

## Introduction

In this lab, students will learn how to build their own Cloud Security Posture Management (CSPM) solution using DuckDB and SQL. You'll provision intentionally insecure AWS resources, export their configurations, and analyze the security posture using DuckDB queries.

## Prerequisites

- Access to AWS Academy Cloud Architecting Sandbox environment
- AWS CloudShell access
- Basic understanding of AWS services and SQL

## Part 1: Set Up Your Environment

### Install DuckDB in CloudShell

First, let's install DuckDB in your CloudShell environment:

```bash
# Create a lab directory
mkdir -p ~/cspm-lab
cd ~/cspm-lab

# Download DuckDB CLI
wget https://github.com/duckdb/duckdb/releases/download/v0.9.2/duckdb_cli-linux-amd64.zip
unzip duckdb_cli-linux-amd64.zip
chmod +x duckdb
./duckdb --version
```

### Create Deployment Script

Create a file named `deploy_insecure_resources.sh` with the following content:

```bash
#!/bin/bash

# Script to provision intentionally insecure AWS resources for DuckDB CSPM lab
# WARNING: These resources are INTENTIONALLY insecure for educational purposes only

echo "Creating insecure resources for DuckDB CSPM lab..."
export AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    export AWS_REGION="us-east-1"
fi

# Create a folder for our lab files
mkdir -p ~/cspm-lab/data
cd ~/cspm-lab

# Generate a unique identifier for resources
UNIQUE_ID=$(date +%H%M%S)
PREFIX="cspmlab${UNIQUE_ID}"
echo "Using resource prefix: $PREFIX"

# 1. Create a VPC with public subnet
echo "Creating VPC and networking components..."
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=${PREFIX}-vpc

# Create subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=${PREFIX}-subnet

# Create internet gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=${PREFIX}-igw
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Create route table and add public route
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=Name,Value=${PREFIX}-rt
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $ROUTE_TABLE_ID

# 2. Create insecure security groups
echo "Creating insecure security groups..."

# Security group with SSH open to the world
SSH_SG_ID=$(aws ec2 create-security-group --group-name ${PREFIX}-ssh-open --description "SG with SSH open to the world" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $SSH_SG_ID --tags Key=Name,Value=${PREFIX}-ssh-open
aws ec2 authorize-security-group-ingress --group-id $SSH_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0

# Security group with RDP open to the world
RDP_SG_ID=$(aws ec2 create-security-group --group-name ${PREFIX}-rdp-open --description "SG with RDP open to the world" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $RDP_SG_ID --tags Key=Name,Value=${PREFIX}-rdp-open
aws ec2 authorize-security-group-ingress --group-id $RDP_SG_ID --protocol tcp --port 3389 --cidr 0.0.0.0/0

# Security group with MySQL open to the world
MYSQL_SG_ID=$(aws ec2 create-security-group --group-name ${PREFIX}-mysql-open --description "SG with MySQL open to the world" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $MYSQL_SG_ID --tags Key=Name,Value=${PREFIX}-mysql-open
aws ec2 authorize-security-group-ingress --group-id $MYSQL_SG_ID --protocol tcp --port 3306 --cidr 0.0.0.0/0

# Security group with all ports open
ALL_OPEN_SG_ID=$(aws ec2 create-security-group --group-name ${PREFIX}-all-open --description "SG with all ports open" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $ALL_OPEN_SG_ID --tags Key=Name,Value=${PREFIX}-all-open
aws ec2 authorize-security-group-ingress --group-id $ALL_OPEN_SG_ID --protocol all --cidr 0.0.0.0/0

# 3. Create EC2 instances with insecure configurations
echo "Creating EC2 instances with insecure configurations..."

# Get latest Amazon Linux 2 AMI
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text)

# Create instance with SSH open to world
aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name vockey --security-group-ids $SSH_SG_ID --subnet-id $SUBNET_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-ssh-instance}]" --associate-public-ip-address

# Create instance with RDP open to world  
aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name vockey --security-group-ids $RDP_SG_ID --subnet-id $SUBNET_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-rdp-instance}]" --associate-public-ip-address

# Create instance with all ports open
aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name vockey --security-group-ids $ALL_OPEN_SG_ID --subnet-id $SUBNET_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-all-open-instance}]" --associate-public-ip-address

# 4. Create S3 buckets with insecure configurations
echo "Creating S3 buckets with insecure configurations..."

# Create public bucket
PUBLIC_BUCKET="${PREFIX}-public-bucket"
aws s3api create-bucket --bucket $PUBLIC_BUCKET --region $AWS_REGION

# Make bucket public
aws s3api put-bucket-policy --bucket $PUBLIC_BUCKET --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Sid\": \"PublicReadGetObject\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::${PUBLIC_BUCKET}/*\"
    }
  ]
}"

# Disable bucket versioning
aws s3api put-bucket-versioning --bucket $PUBLIC_BUCKET --versioning-configuration Status=Suspended

# 5. Create RDS instance with insecure configuration
echo "Creating DB subnet group..."
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.2.0/24" --availability-zone "${AWS_REGION}b" --query 'Subnet.SubnetId' --output text > /tmp/subnet2.txt
SUBNET2_ID=$(cat /tmp/subnet2.txt)
aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value=${PREFIX}-subnet2

# Create DB subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name ${PREFIX}-db-subnet-group \
    --db-subnet-group-description "Subnet group for insecure RDS" \
    --subnet-ids $SUBNET_ID $SUBNET2_ID

echo "Creating RDS instance with insecure configuration..."
aws rds create-db-instance \
    --db-instance-identifier ${PREFIX}-insecure-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password insecurepassword \
    --allocated-storage 20 \
    --vpc-security-group-ids $MYSQL_SG_ID \
    --db-subnet-group-name ${PREFIX}-db-subnet-group \
    --publicly-accessible \
    --no-multi-az \
    --no-storage-encrypted

# 6. Export all configurations to JSON files for DuckDB analysis
echo "Exporting configurations to JSON files..."

# Export security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" > data/security_groups.json

# Export EC2 instances
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" > data/instances.json

# Export S3 buckets and policies
aws s3api list-buckets > data/s3_buckets.json
aws s3api get-bucket-policy --bucket $PUBLIC_BUCKET > data/s3_policies_${PUBLIC_BUCKET}.json 2>/dev/null || echo "{}" > data/s3_policies_${PUBLIC_BUCKET}.json

# Export RDS instances
aws rds describe-db-instances --db-instance-identifier ${PREFIX}-insecure-db > data/rds_instances.json

echo "Resource creation complete! Configuration data exported to the data directory."
echo "VPC ID: $VPC_ID"
echo "Security Group IDs: $SSH_SG_ID, $RDP_SG_ID, $MYSQL_SG_ID, $ALL_OPEN_SG_ID"
echo "S3 Bucket: $PUBLIC_BUCKET"
echo "RDS Instance ID: ${PREFIX}-insecure-db"

echo "PREFIX=$PREFIX" > resource_prefix.txt
```

Make the script executable:

```bash
chmod +x deploy_insecure_resources.sh
```

## Part 2: Deploy Insecure Resources

Run the deployment script to create intentionally insecure resources:

```bash
./deploy_insecure_resources.sh
```

This script will create:
- A VPC with a public subnet
- Security groups with dangerous rules (SSH, RDP, MySQL open to the world)
- EC2 instances with public IP addresses and insecure configurations
- A public S3 bucket with no encryption
- An RDS instance with public access and insecure configuration

## Part 3: Create DuckDB CSPM Queries

Create a file named `cspm_queries.sql` with the following SQL queries:

```sql
-- Connect to DuckDB
-- Run the following command to start DuckDB:
-- ./duckdb cspm.db

-- Create tables from AWS resources data
CREATE TABLE security_groups AS 
SELECT * FROM read_json_auto('data/security_groups.json');

CREATE TABLE instances AS 
SELECT * FROM read_json_auto('data/instances.json');

CREATE TABLE s3_buckets AS 
SELECT * FROM read_json_auto('data/s3_buckets.json');

CREATE TABLE rds_instances AS 
SELECT * FROM read_json_auto('data/rds_instances.json');

-- Create a flattened view of security groups
CREATE OR REPLACE VIEW sg_rules AS
SELECT 
  sg.GroupId,
  sg.GroupName,
  sg.Description,
  sg.VpcId,
  ip.IpProtocol,
  ip.FromPort,
  ip.ToPort,
  ip_range->>'CidrIp' AS CidrIp
FROM security_groups,
  UNNEST(SecurityGroups) AS sg,
  UNNEST(sg.IpPermissions) AS ip,
  UNNEST(ip.IpRanges) AS ip_range;

-- Create a flattened view of EC2 instances
CREATE OR REPLACE VIEW ec2_instances AS
SELECT
  r.ReservationId,
  i.InstanceId,
  i.InstanceType,
  i.SubnetId,
  i.VpcId,
  i.PrivateIpAddress,
  i.PublicIpAddress,
  i.State->>'Name' AS State,
  sg->>'GroupId' AS SecurityGroupId
FROM instances,
  UNNEST(Reservations) AS r,
  UNNEST(r.Instances) AS i,
  UNNEST(i.SecurityGroups) AS sg;

-- CSPM Query 1: Find security groups with SSH (port 22) open to the world
SELECT 
  GroupId,
  GroupName,
  Description,
  IpProtocol,
  FromPort,
  ToPort,
  CidrIp
FROM sg_rules
WHERE 
  (IpProtocol = 'tcp' AND FromPort <= 22 AND ToPort >= 22)
  AND CidrIp = '0.0.0.0/0';

-- CSPM Query 2: Find security groups with RDP (port 3389) open to the world
SELECT 
  GroupId,
  GroupName,
  Description,
  IpProtocol,
  FromPort,
  ToPort,
  CidrIp
FROM sg_rules
WHERE 
  (IpProtocol = 'tcp' AND FromPort <= 3389 AND ToPort >= 3389)
  AND CidrIp = '0.0.0.0/0';

-- CSPM Query 3: Find security groups with database ports open to the world
SELECT 
  GroupId,
  GroupName,
  Description,
  IpProtocol,
  FromPort,
  ToPort,
  CidrIp
FROM sg_rules
WHERE 
  (IpProtocol = 'tcp' AND 
   ((FromPort <= 3306 AND ToPort >= 3306) OR  -- MySQL
    (FromPort <= 5432 AND ToPort >= 5432) OR  -- PostgreSQL
    (FromPort <= 1521 AND ToPort >= 1521) OR  -- Oracle
    (FromPort <= 1433 AND ToPort >= 1433)))   -- MS SQL Server
  AND CidrIp = '0.0.0.0/0';

-- CSPM Query 4: Find security groups that allow all traffic
SELECT 
  GroupId,
  GroupName,
  Description,
  IpProtocol,
  FromPort,
  ToPort,
  CidrIp
FROM sg_rules
WHERE 
  (IpProtocol = '-1' OR IpProtocol = 'all')
  AND CidrIp = '0.0.0.0/0';

-- CSPM Query 5: Find public EC2 instances
SELECT 
  i.InstanceId,
  i.InstanceType,
  i.State,
  i.PublicIpAddress,
  sg.GroupName AS SecurityGroupName,
  sg.Description AS SecurityGroupDescription
FROM ec2_instances i
JOIN sg_rules sg ON i.SecurityGroupId = sg.GroupId
WHERE 
  i.PublicIpAddress IS NOT NULL;

-- CSPM Query 6: Find public RDS instances
SELECT 
  dbi->>'DBInstanceIdentifier' AS DBInstanceId,
  dbi->>'Engine' AS Engine,
  dbi->>'DBInstanceClass' AS DBInstanceClass,
  dbi->>'PubliclyAccessible' AS PubliclyAccessible,
  dbi->>'StorageEncrypted' AS StorageEncrypted,
  dbi->>'MultiAZ' AS MultiAZ
FROM rds_instances,
  UNNEST(DBInstances) AS dbi
WHERE 
  dbi->>'PubliclyAccessible' = 'true';

-- CSPM Query 7: Find RDS instances with unencrypted storage
SELECT 
  dbi->>'DBInstanceIdentifier' AS DBInstanceId,
  dbi->>'Engine' AS Engine,
  dbi->>'DBInstanceClass' AS DBInstanceClass,
  dbi->>'StorageEncrypted' AS StorageEncrypted
FROM rds_instances,
  UNNEST(DBInstances) AS dbi
WHERE 
  dbi->>'StorageEncrypted' = 'false' OR
  dbi->>'StorageEncrypted' IS NULL;

-- CSPM Query 8: Count of security issues by category
WITH security_issues AS (
  SELECT 'SSH Open to World' AS issue, COUNT(*) AS count FROM sg_rules
  WHERE (IpProtocol = 'tcp' AND FromPort <= 22 AND ToPort >= 22) AND CidrIp = '0.0.0.0/0'
  
  UNION ALL
  
  SELECT 'RDP Open to World' AS issue, COUNT(*) AS count FROM sg_rules
  WHERE (IpProtocol = 'tcp' AND FromPort <= 3389 AND ToPort >= 3389) AND CidrIp = '0.0.0.0/0'
  
  UNION ALL
  
  SELECT 'Database Ports Open to World' AS issue, COUNT(*) AS count FROM sg_rules
  WHERE (IpProtocol = 'tcp' AND 
         ((FromPort <= 3306 AND ToPort >= 3306) OR  -- MySQL
          (FromPort <= 5432 AND ToPort >= 5432) OR  -- PostgreSQL
          (FromPort <= 1521 AND ToPort >= 1521) OR  -- Oracle
          (FromPort <= 1433 AND ToPort >= 1433)))   -- MS SQL Server
    AND CidrIp = '0.0.0.0/0'
  
  UNION ALL
  
  SELECT 'All Traffic Allowed' AS issue, COUNT(*) AS count FROM sg_rules
  WHERE (IpProtocol = '-1' OR IpProtocol = 'all') AND CidrIp = '0.0.0.0/0'
  
  UNION ALL
  
  SELECT 'Public EC2 Instances' AS issue, COUNT(*) AS count FROM ec2_instances
  WHERE PublicIpAddress IS NOT NULL
  
  UNION ALL
  
  SELECT 'Public RDS Instances' AS issue, COUNT(*) AS count 
  FROM rds_instances, UNNEST(DBInstances) AS dbi
  WHERE dbi->>'PubliclyAccessible' = 'true'
  
  UNION ALL
  
  SELECT 'Unencrypted RDS Instances' AS issue, COUNT(*) AS count 
  FROM rds_instances, UNNEST(DBInstances) AS dbi
  WHERE dbi->>'StorageEncrypted' = 'false' OR dbi->>'StorageEncrypted' IS NULL
)

SELECT * FROM security_issues
ORDER BY count DESC;
```

## Part 4: Run the CSPM Analysis

Run DuckDB and execute the SQL queries:

```bash
cd ~/cspm-lab
./duckdb cspm.db < cspm_queries.sql
```

To explore interactively:

```bash
./duckdb cspm.db
```

Then run queries from the prompt.

## Part 5: Student Exercises

Now that you have a functioning CSPM system with DuckDB, try completing these exercises:

1.  Create a new SQL query to find EC2 instances that belong to security groups allowing all traffic
    <details>
    <summary>Click to see solution</summary>

    ```sql
    -- Solution for exercise 1 (to be filled in)
    ```
    </details>
2.  Create a query that combines multiple security issues to produce a "risk score" for each resource
    <details>
    <summary>Click to see solution</summary>

    ```sql
    -- Solution for exercise 2 (to be filled in)
    ```
    </details>
3.  Create a query to identify resources that have tags vs. resources that don't have tags
    <details>
    <summary>Click to see solution</summary>

    ```sql
    -- Solution for exercise 3 (to be filled in)
    ```
    </details>
4.  Write a query to find security groups that allow inbound access to privileged ports (0-1024)
    <details>
    <summary>Click to see solution</summary>

    ```sql
    -- Solution for exercise 4 (to be filled in)
    ```
    </details>
5.  Create a view that sh
    <details>
    <summary>Click to see solution</summary>

    ```sql
    -- Solution for exercise 5 (to be filled in)
    ```
    </details>

## Part 6: Clean Up Resources

After you have completed the lab and experimented with the queries, you should clean up the AWS resources to avoid incurring further charges.

A script `destroy_resources.sh` has been provided to automate this process. This script will read the `resource_prefix.txt` file (generated during deployment) to identify and delete the resources created by the `deploy_insecure_resources.sh` script.

To clean up your resources:

1.  Navigate to the lab directory if you are not already there:
    ```bash
    cd ~/cspm-lab
    ```

2.  Make the destroy script executable:
    ```bash
    chmod +x destroy_resources.sh
    ```

3.  Run the destroy script:
    ```bash
    ./destroy_resources.sh
    ```

This script will attempt to delete:
- EC2 instances
- RDS instance
- S3 bucket (including its contents and policy)
- DB Subnet Group
- Security Groups
- VPC components (Internet Gateway, Route Table, Subnets)
- The VPC itself
- Local files (`resource_prefix.txt`, `data/` directory)

**Important Notes:**
- The script will ask for confirmation before proceeding with the deletion of AWS resources.
- Deleting some resources, especially the RDS instance and VPC, can take several minutes.
- The script attempts to delete resources in an order that respects dependencies. However, if you encounter errors (e.g., a VPC not deleting because a Security Group still exists due to a lingering network interface), you may need to wait a few minutes and re-run the script, or manually delete the remaining resources via the AWS Management Console.
- Always verify in the AWS Management Console that all resources with the prefix `cspmlab<TIMESTAMP>` have been successfully deleted after running the script.