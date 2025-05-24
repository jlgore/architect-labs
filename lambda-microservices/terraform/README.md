# QuickMart Lambda Microservices - Terraform Deployment

This directory contains Terraform configuration to deploy the QuickMart serverless microservices architecture on AWS using corrected and validated Lambda functions.

## Architecture Overview

The deployment creates:
- **3 Lambda Functions**: Store Service, Inventory Service, and Gas Price Service
- **PostgreSQL RDS Instance**: Shared database for all services
- **Lambda Function URLs**: HTTP endpoints for each service
- **Security Groups**: Proper network isolation
- **IAM Roles & Policies**: Least privilege access

## Fixed Issues

This Terraform deployment includes all the fixes identified in the manual README validation:

### Database Schema Fixes
- ✅ **Lowercase table names**: `stores`, `inventoryitems`, `gasprices`
- ✅ **Added missing `created_at` column** to stores table
- ✅ **Consistent column naming**: `store_id` instead of `id`
- ✅ **Proper foreign key constraints** with CASCADE deletes
- ✅ **Unique constraint** on `(store_id, fuel_type)` for UPSERT operations

### Lambda Function Fixes
- ✅ **Fixed inter-service validation** with proper payload structure
- ✅ **Robust error handling** and debugging logs
- ✅ **Type conversion** for store_id validation
- ✅ **Proper JSON response formatting**
- ✅ **Environment variable validation**

### SQL Query Fixes
- ✅ **All table names** updated to lowercase
- ✅ **Column names** corrected (`store_id` vs `id`)
- ✅ **RETURNING clauses** fixed for PostgreSQL compatibility

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.9+ (for Lambda function packaging)
- `pip` package installer

## Required AWS Permissions

Your AWS credentials need the following permissions:
- Lambda: Create, update, delete functions and function URLs
- RDS: Create, configure databases and subnet groups
- EC2: Manage VPCs, security groups, and subnets
- IAM: Create and manage roles and policies
- SSM: Store and retrieve parameters (for database password)

## Quick Start

1. **Clone and navigate to the terraform directory:**
   ```bash
   cd lambda-microservices/terraform
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review and customize variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

6. **Get the service URLs:**
   ```bash
   terraform output
   ```

## Configuration Variables

Create a `terraform.tfvars` file with your configuration:

```hcl
# AWS Configuration
aws_region = "us-east-1"
environment = "dev"

# Database Configuration
db_instance_class = "db.t3.micro"
db_storage_size = 20
db_engine_version = "15.7"
db_name = "quickmartdb"
db_username = "quickmartadmin"

# Tags
default_tags = {
  Project = "QuickMart"
  Owner   = "your-name"
}
```

## Database Schema Setup

After deployment, connect to the RDS instance and run the schema:

1. **Get database connection details:**
   ```bash
   terraform output rds_endpoint
   terraform output rds_username
   # Password is stored in SSM Parameter Store
   aws ssm get-parameter --name "/dev/quickmart/db/password" --with-decryption --query 'Parameter.Value' --output text
   ```

2. **Connect and create schema:**
   ```bash
   psql -h <rds_endpoint> -U <username> -d quickmartdb -f database_schema.sql
   ```

   Or use the provided schema file at: `lambda-microservices/terraform/database_schema.sql`

## Testing the Deployment

Once deployed, test the services using the output URLs:

### 1. Store Service Tests

```bash
# Get service URLs
STORE_URL=$(terraform output -raw store_service_url)
INVENTORY_URL=$(terraform output -raw inventory_service_url)
GAS_PRICE_URL=$(terraform output -raw gas_price_service_url)

# Create a store
STORE_RESPONSE=$(curl -s -X POST $STORE_URL \
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

# Extract store_id (requires jq)
STORE_ID=$(echo "$STORE_RESPONSE" | jq -r '.store_id')
echo "Created store ID: $STORE_ID"

# Get store details
curl -X POST $STORE_URL \
  -H "Content-Type: application/json" \
  -d "{
        \"action\": \"getStore\",
        \"store_id\": $STORE_ID
      }"

# List all stores
curl -X POST $STORE_URL \
  -H "Content-Type: application/json" \
  -d '{"action": "listStores"}'
```

### 2. Inventory Service Tests

```bash
# Add item to store
curl -X POST $INVENTORY_URL \
  -H "Content-Type: application/json" \
  -d "{
        \"action\": \"addItemToStore\",
        \"payload\": {
            \"store_id\": $STORE_ID,
            \"item_name\": \"Premium Coffee Beans\",
            \"quantity\": 50,
            \"price\": 12.99
        }
      }"

# Get store inventory
curl -X POST $INVENTORY_URL \
  -H "Content-Type: application/json" \
  -d "{
        \"action\": \"getStoreInventory\",
        \"payload\": {
            \"store_id\": $STORE_ID
        }
      }"
```

### 3. Gas Price Service Tests

```bash
# Update gas price
curl -X POST $GAS_PRICE_URL \
  -H "Content-Type: application/json" \
  -d "{
        \"action\": \"updateGasPrice\",
        \"payload\": {
            \"store_id\": $STORE_ID,
            \"fuel_type\": \"Regular\",
            \"price\": 3.799
        }
      }"

# Get gas prices for store
curl -X POST $GAS_PRICE_URL \
  -H "Content-Type: application/json" \
  -d "{
        \"action\": \"getGasPricesForStore\",
        \"payload\": {
            \"store_id\": $STORE_ID
        }
      }"
```

## File Structure

```
terraform/
├── README.md                     # This file
├── main.tf                       # Main infrastructure configuration
├── variables.tf                  # Input variables
├── outputs.tf                    # Output values
├── versions.tf                   # Provider versions
├── database_schema.sql           # Database schema file
├── modules/
│   └── lambda/
│       ├── main.tf              # Lambda module
│       └── variables.tf         # Lambda module variables
└── lambda_functions/            # Lambda source code
    ├── store_service/
    │   ├── lambda_function.py   # Fixed store service code
    │   └── requirements.txt     # Python dependencies
    ├── inventory_service/
    │   ├── lambda_function.py   # Fixed inventory service code
    │   └── requirements.txt     # Python dependencies
    └── gas_price_service/
        ├── lambda_function.py   # Fixed gas price service code
        └── requirements.txt     # Python dependencies
```

## Key Improvements in This Version

### 1. Database Schema Corrections
- **Lowercase table names**: Matches Lambda code expectations
- **Consistent primary keys**: All use `*_id` naming convention
- **Missing columns added**: `created_at` timestamp for stores
- **Proper constraints**: Foreign keys and unique constraints

### 2. Lambda Function Corrections
- **Fixed store validation**: Uses correct payload structure
- **Improved error handling**: Better debugging and error messages
- **Type safety**: Proper integer conversion for store_id
- **Environment validation**: Checks for required environment variables

### 3. Inter-Service Communication Fixes
- **Payload structure**: StoreService expects `store_id` directly, not in `payload`
- **Response parsing**: Robust JSON parsing with error handling
- **Timeout handling**: 10-second timeout for inter-service calls
- **Status code validation**: Proper HTTP status code checking

### 4. Infrastructure Improvements
- **Modular design**: Reusable Lambda module
- **Automatic packaging**: Dependencies installed automatically
- **Secure password management**: RDS password stored in SSM Parameter Store
- **Proper IAM policies**: Least privilege access

## Troubleshooting

### Common Issues

1. **Lambda packaging errors:**
   - Ensure Python 3.9+ is installed
   - Check that `pip` is available
   - Verify source code paths are correct

2. **Database connection errors:**
   - Check security group rules allow Lambda → RDS
   - Verify RDS instance is in available state
   - Confirm environment variables are set correctly

3. **Inter-service communication errors:**
   - Check CloudWatch logs for detailed error messages
   - Verify Function URLs are correctly set as environment variables
   - Ensure all services are deployed and accessible

### Debugging

1. **Check Lambda logs:**
   ```bash
   aws logs tail /aws/lambda/qm-store-service --follow
   aws logs tail /aws/lambda/qm-inventory-service --follow
   aws logs tail /aws/lambda/qm-gas-price-service --follow
   ```

2. **Verify database schema:**
   ```sql
   \dt  -- List tables
   \d stores  -- Describe stores table
   \d inventoryitems  -- Describe inventory table
   \d gasprices  -- Describe gas prices table
   ```

3. **Test individual components:**
   - Test database connectivity from Lambda
   - Test Function URLs individually
   - Verify environment variables are set

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all data, including the RDS database.

## Security Considerations

- RDS instance is not publicly accessible
- Lambda functions use least privilege IAM roles
- Database password is stored securely in SSM Parameter Store
- Security groups follow principle of least access
- Function URLs have no authentication (suitable for demos only)

## Cost Optimization

- Uses `db.t3.micro` RDS instance (AWS Free Tier eligible)
- Lambda functions use minimal memory (256MB)
- No NAT Gateway required (uses default VPC)
- Storage optimized for minimal cost

## Support

For issues related to this Terraform deployment:
1. Check the troubleshooting section above
2. Review CloudWatch logs for detailed error messages
3. Verify all prerequisites are met
4. Ensure AWS credentials have sufficient permissions

---

**Note**: This is a demonstration/learning environment. For production use, consider additional security measures, monitoring, backup strategies, and high availability configurations.
