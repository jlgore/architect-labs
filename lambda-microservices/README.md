# QuickMart: A Serverless Microservices Lab on AWS

This lab guides you through building and deploying a simplified backend for "QuickMart," a fictional 24/7 online convenience store and gas station, using AWS Lambda microservices, Amazon RDS, and AWS CLI within a CloudShell environment. The architecture emphasizes inter-service communication via Lambda Function URLs and adheres to typical sandbox environment constraints (e.g., using pre-existing IAM roles for Lambda execution).

## Lab Vision: QuickMart

QuickMart allows users to (eventually):
- View available stores.
- Check product inventory at specific stores.
- See current gas prices at stores with gas stations.

We will build the following microservices:
1.  **`StoreServiceLambda`**: Manages store information (ID, name, address).
2.  **`InventoryServiceLambda`**: Manages product inventory per store (item name, quantity, price). This service might call `StoreServiceLambda` to validate store IDs.
3.  **`GasPriceServiceLambda`**: Manages gas prices per store (fuel type, price). This service might also call `StoreServiceLambda`.

All Lambdas will interact with a shared Amazon RDS database using username/password authentication. Communication between Lambdas will be achieved by calling their respective Function URLs (with `AuthType: NONE`), where the target URL is passed as an environment variable to the calling Lambda.

## Prerequisites

- Access to AWS CloudShell.
- AWS CLI configured (this is typically default in CloudShell).
- The ARN of a pre-existing IAM Role that Lambda can assume for execution (e.g., for CloudWatch Logs access, VPC access for RDS, and outbound HTTPS calls). We will assume the role name is `lambda-run-role`.
- Familiarity with basic AWS concepts (VPC, Subnets, Security Groups, RDS, Lambda).

## Lab Overview

1.  **Network Setup**: Create VPC, public and private subnets, NAT Gateway, Route Tables, and Security Groups for Lambdas and RDS.
2.  **Database Setup**: Launch an RDS instance (e.g., MySQL or PostgreSQL) and create the necessary tables for QuickMart.
3.  **`StoreServiceLambda` Deployment**:
    *   Write Python code.
    *   Package with dependencies (if any).
    *   Deploy using `aws lambda create-function`, providing DB credentials as environment variables.
    *   Create and configure its Lambda Function URL.
4.  **`InventoryServiceLambda` Deployment**:
    *   Write Python code (including logic to call `StoreServiceLambda`).
    *   Package with dependencies (e.g., `requests` library).
    *   Deploy, providing DB credentials and the `StoreServiceLambda` Function URL as environment variables.
    *   Create and configure its Lambda Function URL.
5.  **`GasPriceServiceLambda` Deployment** (Similar to `InventoryServiceLambda`).
6.  **Testing**: Invoke Lambda functions via AWS CLI and `curl` to their Function URLs, demonstrating CRUD operations and inter-service calls.
7.  **Clean Up**: Remove all created AWS resources.

---

## Step 1: Network Setup (Using Default VPC)

For simplicity in this sandbox environment, we will utilize the **Default VPC** and its associated **default subnets**. Default subnets are public by design, meaning they have a route to an Internet Gateway, which is suitable for our Lambda functions (accessed via Function URLs) and for allowing Lambdas to make outbound calls (e.g., to other AWS services or other Lambda Function URLs).

Our RDS instance will also be placed in these default subnets, with access strictly controlled by Security Groups.

**1. Identify Your Default VPC and Subnet IDs:**

You'll need these IDs for creating the RDS DB Subnet Group and for configuring Lambda VPC settings if necessary (though for Function URLs and standard AWS SDK calls, explicit Lambda VPC config might not always be needed unless accessing resources within a private network segment).

```bash
REGION="us-east-1" # Or your desired region
echo "Using Region: $REGION"

# Get Default VPC ID - ensure this is copied and pasted carefully if multi-line, or convert to single line
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)
echo "Default VPC ID: $DEFAULT_VPC_ID"

if [ "$DEFAULT_VPC_ID" == "None" ] || [ -z "$DEFAULT_VPC_ID" ]; then
  echo "Error: Could not find Default VPC in region $REGION. Please ensure one exists or adjust the script."
  exit 1
fi

# Get Default Subnet IDs - ensure this is copied and pasted carefully if multi-line, or convert to single line
DEFAULT_SUBNET_IDS_JSON=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" "Name=default-for-az,Values=true" \
  --query "Subnets[*].SubnetId" \
  --output json \
  --region $REGION)
echo "Default Subnet IDs (JSON array): $DEFAULT_SUBNET_IDS_JSON"

# For easier use in subsequent commands, let's try to get at least two as separate variables
# This assumes you have at least two default subnets. Adjust if you have fewer in the target region.
DEFAULT_SUBNET_1_ID=$(echo $DEFAULT_SUBNET_IDS_JSON | jq -r '.[0] // empty')
DEFAULT_SUBNET_2_ID=$(echo $DEFAULT_SUBNET_IDS_JSON | jq -r '.[1] // empty')
# DEFAULT_SUBNET_3_ID=$(echo $DEFAULT_SUBNET_IDS_JSON | jq -r '.[2] // empty') # Optional third

if [ -z "$DEFAULT_SUBNET_1_ID" ] || [ -z "$DEFAULT_SUBNET_2_ID" ]; then
  echo "Error: Could not retrieve at least two default subnet IDs. Check your Default VPC configuration."
  # You might want to handle this more gracefully or ensure your default VPC has enough subnets
else
  echo "Using Subnet 1: $DEFAULT_SUBNET_1_ID"
  echo "Using Subnet 2: $DEFAULT_SUBNET_2_ID"
  # Use these variables for the RDS DB Subnet Group creation later
fi

# Note: The `jq` command is used to parse JSON. CloudShell typically has it.
# If jq is not available, you might need to parse the subnet IDs differently or list them manually.
```
Ensure these commands run successfully and you have your `DEFAULT_VPC_ID` and at least two `DEFAULT_SUBNET_IDs`. These will be used in the RDS setup. No NAT Gateway creation is needed as default subnets are already public.

---

## Step 2: Security Groups

We'll create two security groups within our Default VPC:
- `qm-lambda-sg`: For all QuickMart Lambda functions. This will allow all outbound traffic so Lambdas can call other AWS services, their own Function URLs, and the RDS database. Inbound traffic to Lambdas will be managed by their Function URLs (effectively HTTPS on port 443 from the internet).
- `qm-rds-sg`: For the QuickMart RDS database. This will only allow inbound traffic from the `qm-lambda-sg` on the database port (e.g., 3306 for MySQL).

**1. Create Security Groups:**

```bash
# Variables from Step 1 (ensure DEFAULT_VPC_ID is set)
# REGION should also be set

LAMBDA_SG_NAME="qm-lambda-sg"
RDS_SG_NAME="qm-rds-sg"
DB_PORT=5432 # Changed to PostgreSQL default port

# Create Lambda Security Group
LAMBDA_SG_ID=$(aws ec2 create-security-group \
  --group-name $LAMBDA_SG_NAME \
  --description "Security group for QuickMart Lambda functions" \
  --vpc-id $DEFAULT_VPC_ID \
  --query "GroupId" \
  --output text \
  --region $REGION)
echo "Lambda Security Group ($LAMBDA_SG_NAME) created with ID: $LAMBDA_SG_ID"

# Add outbound rule to Lambda SG (allow all outbound) - Default SGs usually have this.
# aws ec2 authorize-security-group-egress --group-id $LAMBDA_SG_ID --protocol -1 --port -1 --cidr 0.0.0.0/0 --region $REGION
# For default VPCs, the default outbound rule is typically allow all. Explicitly adding it might be redundant or even fail if one already exists.
# We will rely on the default outbound rule for the Lambda SG.

# Create RDS Security Group
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name $RDS_SG_NAME \
  --description "Security group for QuickMart RDS database" \
  --vpc-id $DEFAULT_VPC_ID \
  --query "GroupId" \
  --output text \
  --region $REGION)
echo "RDS Security Group ($RDS_SG_NAME) created with ID: $RDS_SG_ID"

# Add inbound rule to RDS SG to allow traffic from Lambda SG on DB_PORT
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port $DB_PORT \
  --source-group $LAMBDA_SG_ID \
  --region $REGION
echo "Added inbound rule to $RDS_SG_NAME from $LAMBDA_SG_NAME on port $DB_PORT"
```

This setup ensures that only our Lambda functions (within `qm-lambda-sg`) can communicate with the RDS database.

---

## Step 3: RDS Database Setup

We will create an RDS instance using PostgreSQL engine (version can be chosen, e.g., 13 or 14, 15) and a `db.t3.micro` instance class, which is suitable for this lab and sandbox constraints.

**1. Define RDS Configuration:**

```bash
# Variables from Step 1 (ensure DEFAULT_SUBNET_1_ID, DEFAULT_SUBNET_2_ID are set)
# Variables from Step 2 (ensure RDS_SG_ID is set)
# REGION should also be set

DB_INSTANCE_IDENTIFIER="qm-postgres-db"
DB_ENGINE="postgres"
DB_ENGINE_VERSION="15.7" # Updated based on user-provided list. IMPORTANT: Verify this version is available in your REGION.
                         # Use `aws rds describe-db-engine-versions --engine postgres --query "DBEngineVersions[*].EngineVersion" --region $REGION` to list available versions.
DB_INSTANCE_CLASS="db.t3.micro"
DB_STORAGE=20 # In GB, minimum for some RDS configurations.
DB_USER="quickmartadmin"
# !!! IMPORTANT: CHOOSE A STRONG PASSWORD AND STORE IT SECURELY !!!
# You will be prompted for this password if you run the command interactively
# or you can set it directly: DB_PASSWORD='YourStrongPassword123!'
DB_PASSWORD_PLACEHOLDER="YOUR_CHOSEN_STRONG_PASSWORD"
DB_NAME="quickmartdb"
DB_SUBNET_GROUP_NAME="qm-db-subnet-group"

echo "RDS Config:"
echo "  Identifier: $DB_INSTANCE_IDENTIFIER"
echo "  Engine: $DB_ENGINE version $DB_ENGINE_VERSION"
echo "  Class: $DB_INSTANCE_CLASS"
echo "  Master User: $DB_USER"
echo "  Initial DB Name: $DB_NAME"
```

**2. Create DB Subnet Group:**

This group tells RDS in which subnets it can place your database instance.

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
  --db-subnet-group-description "Subnet group for QuickMart RDS" \
  --subnet-ids "$DEFAULT_SUBNET_1_ID" "$DEFAULT_SUBNET_2_ID" \
  --tags Key=Name,Value=$DB_SUBNET_GROUP_NAME \
  --region $REGION
echo "DB Subnet Group ($DB_SUBNET_GROUP_NAME) created."
```

**3. Create RDS Instance:**

This command will start provisioning the PostgreSQL database. It can take several minutes.
**Remember to replace `$DB_PASSWORD_PLACEHOLDER` with your actual chosen password if not providing it directly in the `DB_PASSWORD` variable.**

```bash
aws rds create-db-instance \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --db-instance-class $DB_INSTANCE_CLASS \
  --engine $DB_ENGINE \
  --engine-version $DB_ENGINE_VERSION \
  --master-username $DB_USER \
  --master-user-password $DB_PASSWORD_PLACEHOLDER \
  --allocated-storage $DB_STORAGE \
  --db-name $DB_NAME \
  --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
  --vpc-security-group-ids $RDS_SG_ID \
  --publicly-accessible \
  --no-multi-az \
  --storage-type gp2 \
  --backup-retention-period 0 \
  --tags Key=Name,Value=$DB_INSTANCE_IDENTIFIER \
  --region $REGION
  # --skip-final-snapshot # Add this if you want to delete without a final snapshot (for labs)

echo "RDS instance ($DB_INSTANCE_IDENTIFIER) creation initiated. This will take several minutes."
```

**4. Wait for DB Instance to be Available:**

```bash
_MAX_ATTEMPTS=60 # Wait for up to 30 minutes (60 attempts * 30 seconds)
_ATTEMPT=0
_DB_STATUS=""

echo "Waiting for DB instance ($DB_INSTANCE_IDENTIFIER) to become available..."
while [ $_ATTEMPT -lt $_MAX_ATTEMPTS ]; do
  _DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_IDENTIFIER --query 'DBInstances[0].DBInstanceStatus' --output text --region $REGION)
  echo "Current DB status: $_DB_STATUS"
  if [ "$_DB_STATUS" == "available" ]; then
    echo "DB instance is now available."
    break
  fi
  _ATTEMPT=$((_ATTEMPT + 1))
  sleep 30
done

if [ "$_DB_STATUS" != "available" ]; then
  echo "Error: DB instance ($DB_INSTANCE_IDENTIFIER) did not become available in time."
  # Consider manual check in AWS Console
fi
```

**5. Get the RDS Endpoint:**

Once available, you'll need the endpoint to connect to your database.

```bash
RDS_ENDPOINT_ADDRESS=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region $REGION)

RDS_ENDPOINT_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text \
  --region $REGION)

echo "RDS Endpoint: $RDS_ENDPOINT_ADDRESS"
echo "RDS Port: $RDS_ENDPOINT_PORT"

# Store these in variables for Lambda environment configuration
export QM_RDS_HOST=$RDS_ENDPOINT_ADDRESS
export QM_RDS_PORT=$RDS_ENDPOINT_PORT
export QM_RDS_USER=$DB_USER
export QM_RDS_PASSWORD=$DB_PASSWORD_PLACEHOLDER # Use the actual password here for Lambdas
export QM_RDS_DB_NAME=$DB_NAME
```

**6. Database Schema Creation:**

The tables need to be created in your `quickmartdb` database. You can do this by connecting to the database using a PostgreSQL client like `psql`. CloudShell may have `psql` pre-installed or you can install it. Given the RDS instance is set to `--publicly-accessible` and your CloudShell IP would need to be allowed by the `qm-rds-sg` (or the SG allows 0.0.0.0/0 temporarily, which is not ideal), this is one way. 

Alternatively, a setup Lambda function can be created to run the DDL statements, which is cleaner for automation but adds another Lambda to manage.

For this lab, we'll assume you can connect using `psql` from CloudShell. If `psql` is not available, then creating a setup Lambda is the recommended approach.

**IMPORTANT: For `psql` from CloudShell to connect to the publicly accessible RDS instance, you MUST add an inbound rule to your `qm-rds-sg` Security Group to allow TCP traffic on port 5432 from the internet (0.0.0.0/0). This is for lab simplicity and MUST be secured or removed after schema setup for any real environment.**

**To add the required Security Group rule and then connect with `psql`:**

```bash
# 1. Add an inbound rule to qm-rds-sg to allow all IPs (for lab setup simplicity)
# Ensure RDS_SG_ID and REGION are set from previous steps.
aws ec2 authorize-security-group-ingress --group-id $RDS_SG_ID --protocol tcp --port 5432 --cidr 0.0.0.0/0 --region $REGION
echo "WARNING: Added inbound rule to qm-rds-sg for 0.0.0.0/0 (all IPs) on port 5432. This is for lab setup only."

# 2. Connect using psql (ensure RDS variables and your actual DB password are set)
echo "Attempting psql connection..."
PGPASSWORD=$QM_RDS_PASSWORD psql --host=$RDS_ENDPOINT_ADDRESS --port=$RDS_ENDPOINT_PORT --username=$DB_USER --dbname=$DB_NAME

# REMINDER: After you are done with schema setup, you should remove the 0.0.0.0/0 rule from qm-rds-sg for tighter security.
# To remove (example, use with caution):
# aws ec2 revoke-security-group-ingress --group-id $RDS_SG_ID --protocol tcp --port 5432 --cidr 0.0.0.0/0 --region $REGION
```

Once connected, run the following SQL DDL (PostgreSQL syntax):

```sql
-- Stores Table
CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- InventoryItems Table
CREATE TABLE inventoryitems (
    item_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    quantity INT DEFAULT 0,
    price DECIMAL(10, 2) DEFAULT 0.00,
    CONSTRAINT fk_store
        FOREIGN KEY(store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE
);

-- GasPrices Table
CREATE TABLE gasprices (
    gas_price_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL,
    fuel_type VARCHAR(50) NOT NULL, -- e.g., 'Regular', 'Premium', 'Diesel'
    price DECIMAL(10, 3) NOT NULL, -- Prices per gallon/litre often go to 3 decimal places
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_store_gas
        FOREIGN KEY(store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE,
    CONSTRAINT unique_store_fuel UNIQUE (store_id, fuel_type)
);

-- You might want to add some indexes for performance later on, e.g., on store_id in InventoryItems and GasPrices
CREATE INDEX idx_inventoryitems_store_id ON inventoryitems(store_id);
CREATE INDEX idx_gasprices_store_id ON gasprices(store_id);

-- Verify table creation
\dt
```

Disconnect from `psql`.

**Important Security Note:** The `--publicly-accessible` flag makes the RDS instance technically reachable from the internet if security groups allow. For a production setup, you would typically keep RDS private and access it from Lambdas within the same VPC without public accessibility. For this lab, it simplifies initial schema setup from CloudShell. After schema setup, you could modify the instance to remove public accessibility or tighten the `qm-rds-sg` to only allow specific IPs if needed.

---

## Step 4: `StoreServiceLambda` Deployment

This Lambda manages store information (ID, name, address).

### 1. Create the Lambda Function Package

First, create a directory for the Lambda function and its dependencies:

```bash
# Create a directory for this Lambda function's package
mkdir -p store_service
cd store_service
```

### 2. Create the Lambda Function Code

Create a file named `lambda_function.py` with the following content:

```python
import json
import os
import psycopg2

# Database connection details from environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        raise e  # Re-raise exception to signal error

def lambda_handler(event, context):
    # For Lambda Function URL, the actual request body is in event['body'] as a JSON string
    print(f"Raw event received: {json.dumps(event)}")

    try:
        # Parse the request body
        if 'body' in event and isinstance(event['body'], str):
            print(f"Attempting to parse event body: {event['body']}")
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})  # In case body is already parsed
            print(f"Using event body as is: {body}")
        
        action = body.get('action')
        
        if not action:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing action parameter'}),
                'headers': {'Content-Type': 'application/json'}
            }
        
        if action == 'addStore':
            # Extract store data from the request
            store_data = body.get('store')
            if not store_data or 'name' not in store_data or 'address' not in store_data:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Missing required store data (name, address)'}),
                    'headers': {'Content-Type': 'application/json'}
                }
            
            # Get database connection
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    # Insert new store
                    cur.execute(
                        """
                        INSERT INTO stores (name, address)
                        VALUES (%s, %s)
                        RETURNING store_id, name, address, created_at
                        """,
                        (store_data['name'], store_data['address'])
                    )
                    result = cur.fetchone()
                    conn.commit()
                    
                    # Return the created store
                    return {
                        'statusCode': 201,
                        'body': json.dumps({
                            'store_id': result[0],
                            'name': result[1],
                            'address': result[2],
                            'created_at': result[3].isoformat()
                        }),
                        'headers': {'Content-Type': 'application/json'}
                    }
            finally:
                conn.close()
                
        elif action == 'getStore':
            store_id = body.get('store_id')
            if not store_id:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Missing store_id parameter'}),
                    'headers': {'Content-Type': 'application/json'}
                }
            
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT store_id, name, address, created_at
                        FROM stores
                        WHERE store_id = %s
                        """,
                        (store_id,)
                    )
                    result = cur.fetchone()
                    
                    if not result:
                        return {
                            'statusCode': 404,
                            'body': json.dumps({'error': 'Store not found'}),
                            'headers': {'Content-Type': 'application/json'}
                        }
                    
                    return {
                        'statusCode': 200,
                        'body': json.dumps({
                            'store_id': result[0],
                            'name': result[1],
                            'address': result[2],
                            'created_at': result[3].isoformat()
                        }),
                        'headers': {'Content-Type': 'application/json'}
                    }
            finally:
                conn.close()
                
        elif action == 'listStores':
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT store_id, name, address, created_at
                        FROM stores
                        ORDER BY name
                        """
                    )
                    stores = []
                    for row in cur.fetchall():
                        stores.append({
                            'store_id': row[0],
                            'name': row[1],
                            'address': row[2],
                            'created_at': row[3].isoformat()
                        })
                    
                    return {
                        'statusCode': 200,
                        'body': json.dumps({'stores': stores}),
                        'headers': {'Content-Type': 'application/json'}
                    }
            finally:
                conn.close()
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unknown action: {action}'}),
                'headers': {'Content-Type': 'application/json'}
            }
            
    except json.JSONDecodeError as e:
        print(f"Invalid JSON in request body: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON in request body'}),
            'headers': {'Content-Type': 'application/json'}
        }
    except Exception as e:
        print(f"Error processing request: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error', 'details': str(e)}),
            'headers': {'Content-Type': 'application/json'}
        }
```

### 3. Create a requirements.txt File

Create a `requirements.txt` file to specify the dependencies:

```bash
cat > requirements.txt << EOF
psycopg2-binary==2.9.9
EOF
```

### 4. Install Dependencies and Create Deployment Package

```bash
# Install dependencies into the current directory
python3.9 -m pip install -r requirements.txt -t . --no-cache-dir

# Create the deployment package
zip -r ../store_service.zip .

# Return to the parent directory
cd ..

# Verify the zip file was created
ls -l store_service.zip
```

### 5. Deploy the Lambda Function

Before deploying, ensure you have the following environment variables set:

```bash
# Set required variables for Lambda deployment
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export LAMBDA_ROLE_NAME="lambda-run-role"  # Replace with your IAM role name
export LAMBDA_EXECUTION_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

# Region should be set from earlier steps, if not:
# export REGION="us-east-1"

# RDS variables should be set from Step 3, if not:
# export QM_RDS_HOST=$RDS_ENDPOINT_ADDRESS
# export QM_RDS_PORT=$RDS_ENDPOINT_PORT
# export QM_RDS_DB_NAME=$DB_NAME
# export QM_RDS_USER=$DB_USER
# export QM_RDS_PASSWORD=$DB_PASSWORD_PLACEHOLDER

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "Lambda Role: $LAMBDA_EXECUTION_ROLE_ARN"
echo "Region: $REGION"
echo "RDS Host: $QM_RDS_HOST"
```

```bash
# Set Lambda function name
STORE_LAMBDA_NAME="qm-store-service"

# Create the Lambda function
echo "Deploying $STORE_LAMBDA_NAME..."
aws lambda create-function \
    --function-name $STORE_LAMBDA_NAME \
    --runtime python3.9 \
    --role $LAMBDA_EXECUTION_ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://store_service.zip \
    --environment "Variables={
        DB_HOST='$QM_RDS_HOST',
        DB_PORT='$QM_RDS_PORT',
        DB_NAME='$QM_RDS_DB_NAME',
        DB_USER='$QM_RDS_USER',
        DB_PASSWORD='$QM_RDS_PASSWORD'\
    }" \
    --timeout 30 \
    --memory-size 256 \
    --region $REGION

# Create Function URL
echo "Creating Function URL for $STORE_LAMBDA_NAME..."
aws lambda create-function-url-config \
    --function-name $STORE_LAMBDA_NAME \
    --auth-type NONE \
    --region $REGION

# Add permission for public invocation
echo "Adding public access permission..."
aws lambda add-permission \
    --function-name $STORE_LAMBDA_NAME \
    --statement-id FunctionURLAllowPublicAccess-StoreService \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region $REGION

# Get the Function URL
STORE_SERVICE_URL=$(aws lambda get-function-url-config \
    --function-name $STORE_LAMBDA_NAME \
    --region $REGION \
    --query 'FunctionUrl' \
    --output text)
    
echo "Store Service URL: $STORE_SERVICE_URL"
export STORE_SERVICE_URL
echo "  Using Role: $LAMBDA_EXECUTION_ROLE_ARN"
echo "  DB Host: $QM_RDS_HOST" # For verification
# Do not echo QM_RDS_PASSWORD

# After creation, allow some time for the function to be fully ready.
# You can check its status in the AWS Lambda console.
```

---

## Step 5: `InventoryServiceLambda` Deployment

This Lambda manages product inventory per store (item name, quantity, price). It will also demonstrate inter-service communication by calling `StoreServiceLambda` (e.g., to validate a store ID) using its Function URL.

**1. Create Lambda Function Code (`inventory_lambda_function.py`):**

This Python script uses `psycopg2-binary` for database interaction and `requests` to call `StoreServiceLambda`.

```bash
# Create a directory for this Lambda function's package
mkdir inventory_service_pkg
cd inventory_service_pkg

cat > lambda_function.py << EOF
import json
import os
import psycopg2
import requests # For calling StoreServiceLambda

# Database connection details from environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

# URL for StoreServiceLambda from environment variables
STORE_SERVICE_URL = os.environ.get('STORE_SERVICE_URL')

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        raise e

def validate_store_exists(store_id):
    if not STORE_SERVICE_URL:
        print("STORE_SERVICE_URL environment variable is not set. Cannot validate store.")
        return False
    
    headers = {'Content-Type': 'application/json'}
    validation_payload_dict = {
        'action': 'getStore',
        'store_id': int(store_id)  # Ensure we send an integer
    }
    
    try:
        print(f"Calling StoreServiceLambda at {STORE_SERVICE_URL} to validate store_id: {store_id}")
        print(f"Sending payload: {validation_payload_dict}")
        response = requests.post(STORE_SERVICE_URL, headers=headers, json=validation_payload_dict, timeout=10)
        print(f"Response status code: {response.status_code}")
        print(f"Response text: {response.text}")
        
        response.raise_for_status()
        response_data = response.json()
        
        # Convert both to integers for comparison
        expected_store_id = int(store_id)
        returned_store_id = response_data.get('store_id')
        
        print(f"Expected store_id: {expected_store_id} (type: {type(expected_store_id)})")
        print(f"Returned store_id: {returned_store_id} (type: {type(returned_store_id)})")
        
        # Check if we got a successful response with the correct store_id
        if response.status_code == 200 and isinstance(response_data, dict) and returned_store_id == expected_store_id:
            print(f"Store validation successful for store_id: {store_id}")
            return True
        else:
            print(f"Store validation failed. Response from StoreService: {response_data}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"Error calling StoreServiceLambda: {e}")
        return False
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON response from StoreServiceLambda: {e}. Response text: {response.text if response else 'No response'}")
        return False
    except Exception as e:
        print(f"Unexpected error in store validation: {e}")
        return False

def lambda_handler(event, context):
    print(f"Raw event received: {json.dumps(event)}") # Log the raw event

    try:
        if 'body' in event and isinstance(event['body'], str):
            print(f"Attempting to parse event body: {event['body']}")
            data_for_processing = json.loads(event['body'])
        elif 'action' in event and 'payload' in event: 
            print("Using event directly as data for processing.")
            data_for_processing = event
        else: 
            print("Warning: Could not determine primary data source from event, attempting to use event or event['body'] if dict.")
            body_content = event.get('body', event)
            if isinstance(body_content, str):
                 data_for_processing = json.loads(body_content)
            elif isinstance(body_content, dict):
                 data_for_processing = body_content
            else:
                 raise ValueError("Unable to determine data for processing from event structure.")
        print(f"Data for processing: {json.dumps(data_for_processing)}")

    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in request body: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid JSON format in request body', 'details': str(e)})
        }
    except ValueError as e:
        print(f"ERROR: Problem determining data from event: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid event structure for processing', 'details': str(e)})
        }
    except Exception as e:
        print(f"ERROR: Unexpected error processing event: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error during event processing', 'details': str(e)})
        }

    action = data_for_processing.get('action')
    payload = data_for_processing.get('payload', {})
    response_body = {}
    status_code = 200
    conn = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if action == 'addItemToStore':
            store_id = payload.get('store_id')
            item_name = payload.get('item_name')
            quantity = payload.get('quantity', 0)
            price = payload.get('price', 0.0)

            if not all([store_id, item_name]):
                status_code = 400
                response_body = {'error': 'Missing required fields: store_id, item_name'}
            elif not validate_store_exists(store_id):
                status_code = 404 
                response_body = {'error': f'Store with store_id {store_id} not found or validation failed.'}
            else:
                cursor.execute(
                    "INSERT INTO inventoryitems (store_id, item_name, quantity, price) VALUES (%s, %s, %s, %s) RETURNING item_id",
                    (store_id, item_name, int(quantity), float(price))
                )
                item_id = cursor.fetchone()[0]
                conn.commit()
                response_body = {'message': 'Item added to store successfully', 'item_id': item_id}

        elif action == 'getStoreInventory':
            store_id = payload.get('store_id')
            if not store_id:
                status_code = 400
                response_body = {'error': 'Missing store_id'}
            else:
                cursor.execute("SELECT item_id, item_name, quantity, price FROM inventoryitems WHERE store_id = %s ORDER BY item_name", (store_id,))
                items = cursor.fetchall()
                response_body = [{'item_id': i[0], 'item_name': i[1], 'quantity': i[2], 'price': float(i[3])} for i in items]
        
        elif action == 'updateItemQuantity':
            item_id = payload.get('item_id')
            new_quantity = payload.get('quantity')
            if not item_id or new_quantity is None: 
                status_code = 400
                response_body = {'error': 'Missing required fields: item_id, quantity'}
            else:
                cursor.execute("UPDATE inventoryitems SET quantity = %s WHERE item_id = %s RETURNING store_id", (int(new_quantity), item_id))
                if cursor.rowcount == 0:
                    status_code = 404
                    response_body = {'error': 'Item not found'}
                else:
                    conn.commit()
                    response_body = {'message': 'Item quantity updated successfully', 'item_id': item_id, 'new_quantity': int(new_quantity)}
        else:
            status_code = 400
            response_body = {'error': f'Invalid action: {action}'}

    except psycopg2.Error as db_err:
        print(f"Database operation failed: {db_err}")
        status_code = 500
        response_body = {'error': 'Database operation failed', 'details': str(db_err)}
        if conn: conn.rollback()
    except requests.exceptions.RequestException as req_err: 
        print(f"Request to StoreService failed: {req_err}")
        status_code = 503 
        response_body = {'error': 'Failed to communicate with StoreService', 'details': str(req_err)}
    except Exception as e:
        print(f"Error processing request: {e}")
        status_code = 500
        response_body = {'error': 'Internal server error', 'details': str(e)}
        if conn: conn.rollback()
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("Database connection closed.")

    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(response_body)
    }

EOF

ls -l lambda_function.py
cd .. # Return to the main lambda-microservices directory
```

**Key features of this Lambda code:**
- Similar DB setup to `StoreServiceLambda`.
- Takes `STORE_SERVICE_URL` from environment variables.
- **`validate_store_exists(store_id)` function:** Makes a POST request to `StoreServiceLambda` to check if a store exists before adding inventory.
- Handles actions: `addItemToStore`, `getStoreInventory`, `updateItemQuantity`.
- Error handling includes `requests.exceptions.RequestException` for the inter-service call.

**2. Package the Lambda Function with Dependencies (`psycopg2-binary` and `requests`):**

```bash
# Ensure you are in the directory containing inventory_service_pkg, e.g., lambda-microservices/

# Install dependencies into the package directory
python3.9 -m pip install psycopg2-binary requests -t ./inventory_service_pkg/ --no-cache-dir

# Create the zip file
cd inventory_service_pkg
zip -r ../inventory_service.zip .
cd ..

ls -l inventory_service.zip
```

**3. Deploy `InventoryServiceLambda`:**

Ensure `$QM_STORE_SERVICE_URL` (from Step 4.4) is set in your shell. Also, DB connection variables (`$QM_RDS_HOST`, etc.) and `$LAMBDA_EXECUTION_ROLE_ARN` must be set.

```bash
# Set Lambda specific variables
INVENTORY_LAMBDA_NAME="qm-inventory-service"



echo "Deploying $INVENTORY_LAMBDA_NAME..."
echo "  Using StoreService URL: $QM_STORE_SERVICE_URL"

aws lambda create-function --function-name $INVENTORY_LAMBDA_NAME --runtime python3.9 --role $LAMBDA_EXECUTION_ROLE_ARN --handler lambda_function.lambda_handler --zip-file fileb://inventory_service.zip --environment "Variables={DB_HOST=$QM_RDS_HOST,DB_PORT=$QM_RDS_PORT,DB_NAME=$QM_RDS_DB_NAME,DB_USER=$QM_RDS_USER,DB_PASSWORD=$QM_RDS_PASSWORD,STORE_SERVICE_URL=$QM_STORE_SERVICE_URL}" --timeout 30 --memory-size 256 --region $REGION

# Allow time for deployment.
```

**4. Create Lambda Function URL for `InventoryServiceLambda`:**

```bash
aws lambda create-function-url-config --function-name $INVENTORY_LAMBDA_NAME --auth-type NONE --region $REGION

aws lambda add-permission --function-name $INVENTORY_LAMBDA_NAME --statement-id FunctionURLAllowPublicAccess-InventoryService --action lambda:InvokeFunctionUrl --principal '*' --function-url-auth-type NONE --region $REGION

INVENTORY_SERVICE_URL=$(aws lambda get-function-url-config --function-name $INVENTORY_LAMBDA_NAME --region $REGION --query 'FunctionUrl' --output text)
echo "InventoryServiceLambda Function URL: $INVENTORY_SERVICE_URL"

export QM_INVENTORY_SERVICE_URL=$INVENTORY_SERVICE_URL
```

---

## Step 6: `GasPriceServiceLambda` Deployment

This Lambda manages gas prices for various fuel types at stores. It can also call `StoreServiceLambda` to validate store IDs.

**1. Create Lambda Function Code (`gasprice_lambda_function.py`):**

This Python script uses `psycopg2-binary` for database interaction and `requests` to call `StoreServiceLambda`.

```bash
# Create a directory for this Lambda function's package
mkdir gasprice_service_pkg
cd gasprice_service_pkg

cat > lambda_function.py << EOF
import json
import os
import psycopg2
import requests # For calling StoreServiceLambda
from decimal import Decimal # For handling currency precisely

# Database connection details from environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

# URL for StoreServiceLambda from environment variables
STORE_SERVICE_URL = os.environ.get('STORE_SERVICE_URL')

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        raise e

def validate_store_exists(store_id):
    if not STORE_SERVICE_URL:
        print("STORE_SERVICE_URL environment variable is not set. Cannot validate store.")
        return False
    
    headers = {'Content-Type': 'application/json'}
    validation_payload_dict = {
        'action': 'getStore',
        'store_id': int(store_id)  # Ensure we send an integer
    }
    
    try:
        print(f"Calling StoreServiceLambda at {STORE_SERVICE_URL} to validate store_id: {store_id}")
        print(f"Sending payload: {validation_payload_dict}")
        response = requests.post(STORE_SERVICE_URL, headers=headers, json=validation_payload_dict, timeout=10)
        print(f"Response status code: {response.status_code}")
        print(f"Response text: {response.text}")
        
        response.raise_for_status()
        response_data = response.json()
        
        # Convert both to integers for comparison
        expected_store_id = int(store_id)
        returned_store_id = response_data.get('store_id')
        
        print(f"Expected store_id: {expected_store_id} (type: {type(expected_store_id)})")
        print(f"Returned store_id: {returned_store_id} (type: {type(returned_store_id)})")
        
        # Check if we got a successful response with the correct store_id
        if response.status_code == 200 and isinstance(response_data, dict) and returned_store_id == expected_store_id:
            print(f"Store validation successful for store_id: {store_id}")
            return True
        else:
            print(f"Store validation failed. Response from StoreService: {response_data}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"Error calling StoreServiceLambda: {e}")
        return False
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON response from StoreServiceLambda: {e}. Response text: {response.text if response else 'No response'}")
        return False
    except Exception as e:
        print(f"Unexpected error in store validation: {e}")
        return False

def lambda_handler(event, context):
    print(f"Raw event received: {json.dumps(event)}") # Log the raw event

    try:
        if 'body' in event and isinstance(event['body'], str):
            print(f"Attempting to parse event body: {event['body']}")
            data_for_processing = json.loads(event['body'])
        elif 'action' in event and 'payload' in event: 
            print("Using event directly as data for processing.")
            data_for_processing = event
        else: 
            print("Warning: Could not determine primary data source from event, attempting to use event or event['body'] if dict.")
            body_content = event.get('body', event)
            if isinstance(body_content, str):
                 data_for_processing = json.loads(body_content)
            elif isinstance(body_content, dict):
                 data_for_processing = body_content
            else:
                 raise ValueError("Unable to determine data for processing from event structure.")
        print(f"Data for processing: {json.dumps(data_for_processing)}")

    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in request body: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid JSON format in request body', 'details': str(e)})
        }
    except ValueError as e:
        print(f"ERROR: Problem determining data from event: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid event structure for processing', 'details': str(e)})
        }
    except Exception as e:
        print(f"ERROR: Unexpected error processing event: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error during event processing', 'details': str(e)})
        }

    action = data_for_processing.get('action')
    payload = data_for_processing.get('payload', {})
    response_body = {}
    status_code = 200
    conn = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if action == 'updateGasPrice':
            store_id = payload.get('store_id')
            fuel_type = payload.get('fuel_type')
            price = payload.get('price')

            if not all([store_id, fuel_type, price is not None]):
                status_code = 400
                response_body = {'error': 'Missing required fields: store_id, fuel_type, price'}
            elif not validate_store_exists(store_id):
                status_code = 404
                response_body = {'error': f'Store with store_id {store_id} not found or validation failed.'}
            else:
                cursor.execute(
                    """INSERT INTO gasprices (store_id, fuel_type, price, last_updated)
                       VALUES (%s, %s, %s, CURRENT_TIMESTAMP)
                       ON CONFLICT (store_id, fuel_type)
                       DO UPDATE SET price = EXCLUDED.price, last_updated = CURRENT_TIMESTAMP
                       RETURNING gas_price_id, last_updated""",
                    (store_id, fuel_type, Decimal(str(price)))
                )
                gas_price_id, last_updated_ts = cursor.fetchone()
                conn.commit()
                response_body = {
                    'message': 'Gas price updated/added successfully',
                    'gas_price_id': gas_price_id,
                    'store_id': store_id,
                    'fuel_type': fuel_type,
                    'price': str(Decimal(str(price))), 
                    'last_updated': last_updated_ts.isoformat()
                }

        elif action == 'getGasPricesForStore':
            store_id = payload.get('store_id')
            if not store_id:
                status_code = 400
                response_body = {'error': 'Missing store_id'}
            else:
                cursor.execute(
                    "SELECT gas_price_id, fuel_type, price, last_updated FROM gasprices WHERE store_id = %s ORDER BY fuel_type",
                    (store_id,)
                )
                prices = cursor.fetchall()
                response_body = [
                    {
                        'gas_price_id': p[0],
                        'fuel_type': p[1],
                        'price': str(p[2]), 
                        'last_updated': p[3].isoformat()
                    } for p in prices
                ]
        
        else:
            status_code = 400
            response_body = {'error': f'Invalid action: {action}'}

    except psycopg2.Error as db_err:
        print(f"Database operation failed: {db_err}")
        status_code = 500
        response_body = {'error': 'Database operation failed', 'details': str(db_err)}
        if conn: conn.rollback()
    except requests.exceptions.RequestException as req_err:
        print(f"Request to StoreService failed: {req_err}")
        status_code = 503
        response_body = {'error': 'Failed to communicate with StoreService', 'details': str(req_err)}
    except Exception as e:
        print(f"Error processing request: {e}")
        status_code = 500
        response_body = {'error': 'Internal server error', 'details': str(e)}
        if conn: conn.rollback()
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("Database connection closed.")

    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(response_body)
    }

EOF

ls -l lambda_function.py
cd .. # Return to the main lambda-microservices directory
```

**Key features of this Lambda code:**
- Uses `Decimal` for precise price handling.
- `updateGasPrice` action uses an `INSERT ... ON CONFLICT ... DO UPDATE` (upsert) SQL statement to add or update gas prices based on `store_id` and `fuel_type`.
- `getGasPricesForStore` retrieves all gas prices for a given store.
- Includes a `validate_store_exists` function similar to `InventoryServiceLambda`.

**2. Package the Lambda Function with Dependencies (`psycopg2-binary` and `requests`):**

```bash
# Ensure you are in the directory containing gasprice_service_pkg, e.g., lambda-microservices/

# Install dependencies into the package directory
python3.9 -m pip install psycopg2-binary requests -t ./gasprice_service_pkg/ --no-cache-dir

# Create the zip file
cd gasprice_service_pkg
zip -r ../gasprice_service.zip .
cd ..

ls -l gasprice_service.zip
```

**3. Deploy `GasPriceServiceLambda`:**

Ensure `$QM_STORE_SERVICE_URL`, DB connection variables, and `$LAMBDA_EXECUTION_ROLE_ARN` are set.

```bash
# Set Lambda specific variables
GASPRICE_LAMBDA_NAME="qm-gasprice-service"



echo "Deploying $GASPRICE_LAMBDA_NAME..."

aws lambda create-function --function-name $GASPRICE_LAMBDA_NAME --runtime python3.9 --role $LAMBDA_EXECUTION_ROLE_ARN --handler lambda_function.lambda_handler --zip-file fileb://gasprice_service.zip --environment "Variables={DB_HOST=$QM_RDS_HOST,DB_PORT=$QM_RDS_PORT,DB_NAME=$QM_RDS_DB_NAME,DB_USER=$QM_RDS_USER,DB_PASSWORD=$QM_RDS_PASSWORD,STORE_SERVICE_URL=$QM_STORE_SERVICE_URL}" --timeout 30 --memory-size 256 --region $REGION

# Allow time for deployment.
```

**4. Create Lambda Function URL for `GasPriceServiceLambda`:**

```bash
aws lambda create-function-url-config --function-name $GASPRICE_LAMBDA_NAME --auth-type NONE --region $REGION

aws lambda add-permission --function-name $GASPRICE_LAMBDA_NAME --statement-id FunctionURLAllowPublicAccess-GasPriceService --action lambda:InvokeFunctionUrl --principal '*' --function-url-auth-type NONE --region $REGION

GASPRICE_SERVICE_URL=$(aws lambda get-function-url-config --function-name $GASPRICE_LAMBDA_NAME --region $REGION --query 'FunctionUrl' --output text)
echo "GasPriceServiceLambda Function URL: $GASPRICE_SERVICE_URL"

export QM_GASPRICE_SERVICE_URL=$GASPRICE_SERVICE_URL
```

---

## Step 7: Testing the Microservices

Now, let's test the deployed QuickMart microservices. Ensure you have the Function URLs for each service exported as shell variables in your CloudShell environment:
- `$QM_STORE_SERVICE_URL` (from Step 4.4)
- `$QM_INVENTORY_SERVICE_URL` (from Step 5.4)
- `$QM_GASPRICE_SERVICE_URL` (from Step 6.4)

We will use `curl` to send POST requests with JSON payloads to these URLs.

**1. Test `StoreServiceLambda`:**

   a. **Add a New Store:**

      ```bash
      # Ensure QM_STORE_SERVICE_URL is set
      echo "Store Service URL: $QM_STORE_SERVICE_URL"

      # Create store and capture the response
      STORE_RESPONSE=$(curl -s -X POST $QM_STORE_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d '{
              "action": "addStore",
              "store": {
                  "name": "QuickMart Central",
                  "address": "123 Main St",
                  "city": "Anytown"
              }
            }')
      
      echo "Store creation response: $STORE_RESPONSE"
      
      # Try to extract store_id from response (requires jq)
      if command -v jq &> /dev/null; then
          TEST_STORE_ID=$(echo "$STORE_RESPONSE" | jq -r '.store_id // empty')
          if [ -n "$TEST_STORE_ID" ] && [ "$TEST_STORE_ID" != "null" ]; then
              echo "Automatically extracted TEST_STORE_ID: $TEST_STORE_ID"
              export TEST_STORE_ID
          else
              echo "Could not extract store_id automatically. Please set manually:"
              echo "export TEST_STORE_ID=<store_id_from_response>"
          fi
      else
          echo "jq not available. Please manually extract store_id from response above and run:"
          echo "export TEST_STORE_ID=<store_id_from_response>"
      fi
      ```

   b. **Get Store Details:**

      ```bash
      curl -X POST $QM_STORE_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"getStore\",
              \"store_id\": $TEST_STORE_ID
            }"
      # Expected: JSON response with the details of "QuickMart Central"
      ```

   c. **List All Stores:**

      ```bash
      curl -X POST $QM_STORE_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d '{
              "action": "listStores"
            }'
      # Expected: JSON array containing "QuickMart Central" and any other stores
      ```

**2. Test `InventoryServiceLambda`:**

   a. **Add Item to Store (tests inter-Lambda call for store validation):**

      ```bash
      # Ensure QM_INVENTORY_SERVICE_URL and TEST_STORE_ID are set
      echo "Inventory Service URL: $QM_INVENTORY_SERVICE_URL"
      echo "Using Store ID: $TEST_STORE_ID"
      
      # Check if TEST_STORE_ID is set
      if [ -z "$TEST_STORE_ID" ]; then
          echo "ERROR: TEST_STORE_ID is not set. Please run the store creation test first."
          echo "Or manually set: export TEST_STORE_ID=<your_store_id>"
          exit 1
      fi

      curl -X POST $QM_INVENTORY_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"addItemToStore\",
              \"payload\": {
                  \"store_id\": $TEST_STORE_ID,
                  \"item_name\": \"Premium Coffee Beans\",
                  \"quantity\": 50,
                  \"price\": 12.99
              }
            }"
      # Expected: JSON response with "Item added to store successfully" and an item_id
      ```

   b. **Add Another Item:**
      ```bash
      curl -X POST $QM_INVENTORY_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"addItemToStore\",
              \"payload\": {
                  \"store_id\": $TEST_STORE_ID,
                  \"item_name\": \"Bottled Water 1L\",
                  \"quantity\": 100,
                  \"price\": 1.50
              }
            }"
      ```

   c. **Get Store Inventory:**

      ```bash
      curl -X POST $QM_INVENTORY_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"getStoreInventory\",
              \"payload\": {
                  \"store_id\": $TEST_STORE_ID
              }
            }"
      # Expected: JSON array with "Premium Coffee Beans" and "Bottled Water 1L"
      ```

   d. **Update Item Quantity:**
      ```bash
      # First, you'll need to set TEST_ITEM_ID from a previous response, or manually set it:
      # export TEST_ITEM_ID=1 # Replace with actual item_id
      echo "Using TEST_ITEM_ID: $TEST_ITEM_ID"
      
      if [ -z "$TEST_ITEM_ID" ]; then
          echo "ERROR: TEST_ITEM_ID is not set. Please get item_id from inventory list or item creation."
          echo "Or manually set: export TEST_ITEM_ID=<your_item_id>"
      else
          curl -X POST $QM_INVENTORY_SERVICE_URL \
            -H "Content-Type: application/json" \
            -d "{
                  \"action\": \"updateItemQuantity\",
                  \"payload\": {
                      \"item_id\": $TEST_ITEM_ID,
                      \"quantity\": 45
                  }
                }"
      fi
      # Expected: JSON response with "Item quantity updated successfully"
      ```

**3. Test `GasPriceServiceLambda`:**

   a. **Update/Add Gas Price (tests inter-Lambda call for store validation):**

      ```bash
      # Ensure QM_GASPRICE_SERVICE_URL and TEST_STORE_ID are set
      echo "Gas Price Service URL: $QM_GASPRICE_SERVICE_URL"
      echo "Using Store ID: $TEST_STORE_ID"
      
      # Check if TEST_STORE_ID is set
      if [ -z "$TEST_STORE_ID" ]; then
          echo "ERROR: TEST_STORE_ID is not set. Please run the store creation test first."
          exit 1
      fi

      curl -X POST $QM_GASPRICE_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"updateGasPrice\",
              \"payload\": {
                  \"store_id\": $TEST_STORE_ID,
                  \"fuel_type\": \"Regular\",
                  \"price\": 3.799
              }
            }"
      # Expected: JSON response with "Gas price updated/added successfully"
      ```

   b. **Update/Add Another Gas Price:**
      ```bash
      curl -X POST $QM_GASPRICE_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"updateGasPrice\",
              \"payload\": {
                  \"store_id\": $TEST_STORE_ID,
                  \"fuel_type\": \"Premium\",
                  \"price\": 4.299
              }
            }"
      ```

   c. **Get Gas Prices for Store:**

      ```bash
      curl -X POST $QM_GASPRICE_SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "{
              \"action\": \"getGasPricesForStore\",
              \"payload\": {
                  \"store_id\": $TEST_STORE_ID
              }
            }"
      # Expected: JSON array with "Regular" and "Premium" gas prices for the store
      ```

**Troubleshooting Test Failures:**
- **Check Lambda Logs:** If a `curl` command fails or returns an unexpected error (like a 5xx status code from the Lambda Function URL), the first place to look is Amazon CloudWatch Logs for the respective Lambda function. The `print()` statements in the Lambda code will appear there and can provide clues about database connection issues, errors during inter-service calls, or other exceptions.
- **Verify URLs:** Double-check that `$QM_STORE_SERVICE_URL`, `$QM_INVENTORY_SERVICE_URL`, and `$QM_GASPRICE_SERVICE_URL` are correctly set.
- **Verify Payloads:** Ensure your JSON payloads in the `curl` commands are correctly formatted.
- **DB Data:** If `get` operations return empty or unexpected data, ensure the corresponding `add` or `update` operations were successful and committed to the database. You can use `psql` to inspect the database tables directly if needed.

---

## Step 8: Cleanup

This section provides commands to delete the AWS resources created during this lab. Run these commands carefully in your CloudShell environment.

**Important Notes Before Cleanup:**
*   **Order of Deletion:** The order of commands is important to avoid dependency errors. For example, you must delete RDS instances before their DB Subnet Groups.
*   **Resource Naming:** The commands assume you used the resource names defined in this guide (e.g., `StoreServiceLambda`, `quickmart-db`, `qm-lambda-sg`). If you used different names, you'll need to adjust the commands accordingly.
*   **Pre-existing Roles:** This guide assumes you used a pre-existing IAM role (`lambda-run-role`). **This cleanup script will NOT delete that IAM role.**
*   **Confirmation:** Some commands may ask for confirmation or take time to complete.
*   **Region:** Ensure your AWS CLI is configured for the correct region where you deployed these resources (e.g., `us-east-1` as used in the examples). The `REGION` variable should be set.

```bash
# Ensure REGION variable is set, e.g.:
# REGION="us-east-1"
# echo "Using Region: $REGION for cleanup"

# 1. Delete Lambda Functions
# This will also delete their associated Function URLs.
LAMBDA_FUNCTIONS=("StoreServiceLambda" "InventoryServiceLambda" "GasPriceServiceLambda")
for LAMBDA_NAME in "${LAMBDA_FUNCTIONS[@]}"; do
  echo "Deleting Lambda function: $LAMBDA_NAME..."
  aws lambda delete-function --function-name "$LAMBDA_NAME" --region "$REGION"
  if [ $? -eq 0 ]; then
    echo "Successfully deleted Lambda: $LAMBDA_NAME"
  else
    echo "Failed to delete Lambda: $LAMBDA_NAME or it might not exist."
  fi

  # Delete associated CloudWatch Log Group
  LOG_GROUP_NAME="/aws/lambda/$LAMBDA_NAME"
  echo "Deleting CloudWatch Log Group: $LOG_GROUP_NAME..."
  aws logs delete-log-group --log-group-name "$LOG_GROUP_NAME" --region "$REGION"
  if [ $? -eq 0 ]; then
    echo "Successfully deleted Log Group: $LOG_GROUP_NAME"
  else
    echo "Failed to delete Log Group: $LOG_GROUP_NAME or it might not exist."
  fi
done

# 2. Delete RDS Database Instance
DB_INSTANCE_IDENTIFIER="qm-postgres-db" # As defined in Step 3
echo "Deleting RDS DB instance: $DB_INSTANCE_IDENTIFIER (this may take several minutes)..."
aws rds delete-db-instance \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --skip-final-snapshot \
  --delete-automated-backups \
  --region "$REGION"

echo "Waiting for RDS instance ($DB_INSTANCE_IDENTIFIER) to be fully deleted..."
_MAX_ATTEMPTS_RDS_DELETE=60 # Wait for up to 30 minutes
_ATTEMPT_RDS_DELETE=0
while [ $_ATTEMPT_RDS_DELETE -lt $_MAX_ATTEMPTS_RDS_DELETE ]; do
  aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --region "$REGION" > /dev/null 2>&1
  if [ $? -ne 0 ]; then # Error means instance not found, likely deleted
    echo "RDS instance ($DB_INSTANCE_IDENTIFIER) appears to be deleted."
    break
  fi
  echo "RDS instance ($DB_INSTANCE_IDENTIFIER) still deleting... attempt $((_ATTEMPT_RDS_DELETE + 1)) of $_MAX_ATTEMPTS_RDS_DELETE"
  _ATTEMPT_RDS_DELETE=$((_ATTEMPT_RDS_DELETE + 1))
  sleep 30
done

if [ $_ATTEMPT_RDS_DELETE -eq $_MAX_ATTEMPTS_RDS_DELETE ]; then
  echo "Timed out waiting for RDS instance ($DB_INSTANCE_IDENTIFIER) to delete. Please check AWS Console."
fi

# 3. Delete DB Subnet Group
DB_SUBNET_GROUP_NAME="qm-db-subnet-group" # As defined in Step 3
echo "Deleting DB Subnet Group: $DB_SUBNET_GROUP_NAME..."
aws rds delete-db-subnet-group \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --region "$REGION"
if [ $? -eq 0 ]; then
  echo "Successfully deleted DB Subnet Group: $DB_SUBNET_GROUP_NAME"
else
  echo "Failed to delete DB Subnet Group: $DB_SUBNET_GROUP_NAME. Ensure the RDS instance is fully deleted."
fi

# 4. Delete Security Groups
# Re-fetch Security Group IDs by name in case the shell variables are not set
LAMBDA_SG_NAME="qm-lambda-sg"
RDS_SG_NAME="qm-rds-sg"

echo "Attempting to delete Security Group: $LAMBDA_SG_NAME"
LAMBDA_SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$LAMBDA_SG_NAME" --query "SecurityGroups[0].GroupId" --output text --region "$REGION" 2>/dev/null)
if [ -n "$LAMBDA_SG_ID" ] && [ "$LAMBDA_SG_ID" != "None" ]; then
  aws ec2 delete-security-group --group-id "$LAMBDA_SG_ID" --region "$REGION"
  if [ $? -eq 0 ]; then
    echo "Successfully deleted Security Group: $LAMBDA_SG_NAME (ID: $LAMBDA_SG_ID)"
  else
    echo "Failed to delete Security Group: $LAMBDA_SG_NAME (ID: $LAMBDA_SG_ID). It might have dependencies or may have already been deleted."
  fi
else
  echo "Security Group $LAMBDA_SG_NAME not found or ID could not be retrieved."
fi

echo "Attempting to delete Security Group: $RDS_SG_NAME"
RDS_SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$RDS_SG_NAME" --query "SecurityGroups[0].GroupId" --output text --region "$REGION" 2>/dev/null)
if [ -n "$RDS_SG_ID" ] && [ "$RDS_SG_ID" != "None" ]; then
  aws ec2 delete-security-group --group-id "$RDS_SG_ID" --region "$REGION"
  if [ $? -eq 0 ]; then
    echo "Successfully deleted Security Group: $RDS_SG_NAME (ID: $RDS_SG_ID)"
  else
    echo "Failed to delete Security Group: $RDS_SG_NAME (ID: $RDS_SG_ID). It might have dependencies (like rules from other SGs) or may have already been deleted."
  fi
else
  echo "Security Group $RDS_SG_NAME not found or ID could not be retrieved."
fi

# 5. Verify Cleanup (Optional)
echo "Cleanup process initiated. Please verify in the AWS Console that all resources (Lambdas, RDS instance, Subnet Group, Security Groups, Log Groups) have been removed to avoid unexpected charges."
echo "Remember, the IAM role 'lambda-run-role' was not part of this cleanup."
```

---

This is the foundational structure. We will now populate each section with the necessary code and AWS CLI commands.
