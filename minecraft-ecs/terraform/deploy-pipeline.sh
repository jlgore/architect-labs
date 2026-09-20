#!/bin/bash

# Minecraft Data Pipeline Deployment Script
set -e

echo "🎮 Minecraft Data Pipeline Deployment"
echo "======================================"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Get current AWS account and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo "📍 Deploying to Account: $ACCOUNT_ID in Region: $REGION"
echo ""

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

# Plan the deployment
echo "📋 Planning Terraform deployment..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "🚀 Do you want to apply this plan? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Apply the plan
echo "🚀 Deploying infrastructure..."
terraform apply tfplan

# Get outputs
echo ""
echo "📊 Data Pipeline Outputs:"
echo "========================"
terraform output

# Wait a moment for resources to be ready
echo ""
echo "⏳ Waiting for resources to initialize..."
sleep 30

# Get bucket names for later use
DATA_LAKE_BUCKET=$(terraform output -raw data_lake_bucket)
LOGS_BUCKET=$(terraform output -raw logs_bucket)
ATHENA_WORKGROUP=$(terraform output -raw athena_workgroup_name)
GLUE_DATABASE=$(terraform output -raw glue_database_name)

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🔍 Next Steps:"
echo "=============="
echo "1. Wait for VPC Flow Logs to start collecting (immediate)"
echo "2. Connect players to your Minecraft server to generate logs"
echo "3. Wait for Glue jobs to run (every hour) or trigger manually:"
echo "   aws glue start-job-run --job-name minecraft-log-processor"
echo "   aws glue start-job-run --job-name vpc-flow-log-processor"
echo ""
echo "4. Query data in Athena:"
echo "   - Open AWS Console → Athena"
echo "   - Select workgroup: $ATHENA_WORKGROUP"
echo "   - Use database: $GLUE_DATABASE"
echo "   - Run the pre-built named queries"
echo ""
echo "📦 S3 Buckets Created:"
echo "   - Raw Logs: s3://$LOGS_BUCKET"
echo "   - Processed Data: s3://$DATA_LAKE_BUCKET"
echo ""
echo "🔧 Useful Commands:"
echo "=================="
echo "# Check Glue job status"
echo "aws glue get-job-runs --job-name minecraft-log-processor --max-items 5"
echo ""
echo "# List S3 objects in logs bucket"
echo "aws s3 ls s3://$LOGS_BUCKET/ --recursive"
echo ""
echo "# List processed data"
echo "aws s3 ls s3://$DATA_LAKE_BUCKET/processed-data/ --recursive"
echo ""
echo "# Run Glue crawler to discover new data"
echo "aws glue start-crawler --name minecraft-logs-crawler"
echo ""
echo "# Query player statistics with AWS CLI"
echo "aws athena start-query-execution \\"
echo "  --query-string \"SELECT * FROM player_statistics LIMIT 10;\" \\"
echo "  --work-group $ATHENA_WORKGROUP \\"
echo "  --result-configuration OutputLocation=s3://$(terraform output -raw athena_results_bucket)/cli-results/"
echo ""
echo "🎯 Sample Athena Queries:"
echo "========================"
echo "-- Top players by death count"
echo "SELECT player_name, death_count, login_count"
echo "FROM player_statistics"
echo "WHERE player_name IS NOT NULL"
echo "ORDER BY death_count DESC LIMIT 10;"
echo ""
echo "-- Network traffic summary"
echo "SELECT total_flows, minecraft_flows, unique_source_ips"
echo "FROM network_statistics"
echo "ORDER BY stats_calculated_at DESC LIMIT 1;"
echo ""
echo "🎮 Happy Gaming and Analytics!" 