# Complete Minecraft Data Pipeline Setup Guide

This guide walks you through deploying a complete Minecraft analytics data pipeline on AWS and using automated bots to generate realistic test data.

## 🎯 What You'll Build

A comprehensive data pipeline that:
- **Captures** Minecraft server logs and VPC network traffic
- **Processes** logs with AWS Glue to extract player analytics
- **Stores** processed data in a data lake on S3
- **Analyzes** data with Amazon Athena SQL queries
- **Generates** test data using automated Minecraft bots

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (>= 1.0.0)
4. **Bun runtime** for running the bots
5. **Minecraft server** (will be deployed via ECS)

## 🚀 Step 1: Deploy the Infrastructure

### 1.1 Deploy the Minecraft Server and Data Pipeline

```bash
# Navigate to the terraform directory
cd minecraft-ecs/terraform

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

This deploys:
- **ECS Minecraft Server** on Fargate
- **VPC with Flow Logs** enabled
- **S3 Data Lake** for storing processed data
- **Kinesis Firehose** for streaming logs
- **AWS Glue** jobs for data processing
- **Amazon Athena** for analytics queries

### 1.2 Get Your Server IP

After deployment, get your Minecraft server's public IP:

```bash
terraform output minecraft_server_public_ip
```

### 1.3 Verify Server is Running

Check the ECS service status:

```bash
aws ecs describe-services \
  --cluster minecraft-cluster \
  --services minecraft-service \
  --query 'services[0].runningCount'
```

## 🤖 Step 2: Set Up the Analytics Bots

### 2.1 Install Bot Dependencies

```bash
# Navigate to the bots directory
cd minecraft-ecs/minecraft-bots

# Run the setup script
./setup.sh
```

Or manually:

```bash
# Install Bun if not already installed
curl -fsSL https://bun.sh/install | bash

# Install dependencies
bun install

# Make scripts executable
chmod +x *.js
```

### 2.2 Configure Server Connection

Set your Minecraft server IP:

```bash
export MINECRAFT_HOST=your-server-ip  # From terraform output
export MINECRAFT_PORT=25565
```

### 2.3 Test Connection

```bash
bun run test-connection.js
```

If this fails, ensure your Minecraft server is in offline mode.

## 🎮 Step 3: Generate Test Data

### 3.1 Quick Demo (Recommended First)

```bash
# Run 3 bots for 10 minutes
bun run index.js demo
```

This creates:
- Player login/logout events
- Chat messages
- Movement activities
- Basic server interactions

### 3.2 Generate Death Statistics

```bash
# Run specialized death bots
bun run death-bots.js 5 600  # 5 bots for 10 minutes
```

This creates:
- Multiple death events per bot
- Various death scenarios (fall, lava, drowning, etc.)
- Respawn cycles
- Death-related chat messages

### 3.3 Long-term Data Generation

```bash
# Run continuous bot spawning
bun run index.js continuous
```

This maintains:
- 5 active bots at all times
- Varied behaviors (chat, exploration, normal)
- Realistic session durations
- Continuous data flow

### 3.4 Stress Test the Pipeline

```bash
# Run stress test with waves of bots
bun run index.js stress
```

This creates:
- 5 waves of increasing bot counts (2, 4, 6, 8, 10)
- High-volume log generation
- Connection/disconnection patterns
- Server performance testing

## 📊 Step 4: Monitor Data Flow

### 4.1 Check Raw Logs in S3

```bash
# Get bucket names
DATA_LAKE_BUCKET=$(terraform output -raw data_lake_bucket)
LOGS_BUCKET=$(terraform output -raw logs_bucket)

# Check for incoming logs
aws s3 ls s3://$LOGS_BUCKET/minecraft-container-logs/ --recursive
aws s3 ls s3://$LOGS_BUCKET/vpc-flow-logs/ --recursive
```

### 4.2 Monitor Glue Job Processing

```bash
# Check Glue job runs
aws glue get-job-runs --job-name minecraft-log-processor --max-items 5
aws glue get-job-runs --job-name vpc-flow-log-processor --max-items 5
```

### 4.3 Trigger Manual Processing

```bash
# Manually trigger Glue jobs (don't wait for hourly schedule)
aws glue start-job-run --job-name minecraft-log-processor
aws glue start-job-run --job-name vpc-flow-log-processor
```

## 🔍 Step 5: Analyze the Data

### 5.1 Access Athena

1. Open AWS Console → Amazon Athena
2. Select workgroup: `minecraft-analytics`
3. Use database: `minecraft_analytics`

### 5.2 Run Pre-built Queries

The deployment includes several named queries:

**Player Death Statistics:**
```sql
SELECT 
    player_name,
    death_count,
    login_count,
    CASE 
        WHEN login_count > 0 THEN CAST(death_count AS DOUBLE) / CAST(login_count AS DOUBLE)
        ELSE 0 
    END as deaths_per_session
FROM player_statistics
WHERE player_name IS NOT NULL
ORDER BY death_count DESC
LIMIT 20;
```

**Server Activity Summary:**
```sql
SELECT 
    total_events,
    unique_players,
    total_deaths,
    total_chat_messages,
    CASE 
        WHEN total_logins > 0 THEN CAST(total_deaths AS DOUBLE) / CAST(total_logins AS DOUBLE)
        ELSE 0 
    END as overall_death_rate
FROM server_statistics
ORDER BY stats_calculated_at DESC
LIMIT 1;
```

**Network Traffic Analysis:**
```sql
SELECT 
    total_flows,
    minecraft_flows,
    unique_source_ips,
    CASE 
        WHEN total_flows > 0 THEN CAST(minecraft_flows AS DOUBLE) / CAST(total_flows AS DOUBLE) * 100
        ELSE 0 
    END as minecraft_traffic_percentage
FROM network_statistics
ORDER BY stats_calculated_at DESC
LIMIT 1;
```

### 5.3 Bot-Specific Analytics

Query data generated by your bots:

```sql
-- Bot activity summary
SELECT 
    player_name,
    death_count,
    chat_message_count,
    login_count,
    first_seen,
    last_seen
FROM player_statistics
WHERE player_name LIKE '%Bot%'
ORDER BY death_count DESC;

-- Hourly bot activity
SELECT 
    hour,
    COUNT(DISTINCT player_name) as unique_bots,
    COUNT(CASE WHEN event_type = 'player_death' THEN 1 END) as deaths,
    COUNT(CASE WHEN event_type = 'chat_message' THEN 1 END) as messages
FROM minecraft_events
WHERE player_name LIKE '%Bot%'
GROUP BY hour
ORDER BY hour DESC;
```

## 📈 Step 6: Advanced Analytics

### 6.1 Time-based Analysis

```sql
-- Peak activity hours
SELECT 
    hour,
    COUNT(*) as total_events,
    COUNT(DISTINCT player_name) as unique_players
FROM minecraft_events
GROUP BY hour
ORDER BY total_events DESC;
```

### 6.2 Player Behavior Patterns

```sql
-- Most active players
SELECT 
    player_name,
    total_events,
    chat_message_count,
    death_count,
    ROUND(total_events::DOUBLE / login_count, 2) as events_per_session
FROM player_statistics
WHERE login_count > 0
ORDER BY total_events DESC
LIMIT 10;
```

### 6.3 Network Security Analysis

```sql
-- Connection patterns
SELECT 
    srcaddr,
    connection_count,
    successful_connections,
    failed_connections,
    ROUND(success_rate * 100, 2) as success_percentage
FROM connection_statistics
WHERE traffic_type = 'minecraft'
ORDER BY connection_count DESC;
```

## 🎯 Step 7: Demonstration Scenarios

### 7.1 Basic Demo (5 minutes)

```bash
# Quick demonstration
bun run index.js demo
```

Wait 5 minutes, then show:
- Real-time bot activity in terminal
- Server logs in CloudWatch
- Raw data appearing in S3

### 7.2 Death Analytics Demo (10 minutes)

```bash
# Generate death statistics
bun run death-bots.js 3 600
```

After Glue processing, show:
- Player death rankings
- Death-to-session ratios
- Death event patterns

### 7.3 Full Pipeline Demo (30 minutes)

```bash
# Start continuous bots
bun run index.js continuous
```

Demonstrate:
- Live data ingestion
- Glue job processing
- Athena query results
- Network traffic analysis

## 🛠️ Troubleshooting

### Common Issues

**Bots can't connect:**
- Ensure Minecraft server is running
- Check server is in offline mode (`online-mode=false`)
- Verify correct IP and port

**No data in Athena:**
- Wait for Glue jobs to run (hourly schedule)
- Manually trigger Glue jobs
- Check S3 for raw log data

**Glue jobs failing:**
- Check CloudWatch logs for Glue jobs
- Verify IAM permissions
- Ensure S3 buckets are accessible

**High costs:**
- Monitor Glue job frequency
- Adjust bot activity levels
- Use smaller instance types for testing

### Monitoring Commands

```bash
# Check ECS service
aws ecs describe-services --cluster minecraft-cluster --services minecraft-service

# Check S3 data
aws s3 ls s3://$LOGS_BUCKET/ --recursive | head -20

# Check Glue job status
aws glue get-job-runs --job-name minecraft-log-processor --max-items 3

# Check Athena query history
aws athena list-query-executions --work-group minecraft-analytics --max-items 5
```

## 🧹 Cleanup

When you're done testing:

```bash
# Stop bots
# Press Ctrl+C in bot terminals

# Destroy infrastructure
cd minecraft-ecs/terraform
terraform destroy
```

## 🎉 Success Metrics

You'll know the pipeline is working when you see:

1. **Bots connecting** to Minecraft server
2. **Logs appearing** in CloudWatch and S3
3. **Glue jobs completing** successfully
4. **Data available** in Athena tables
5. **Meaningful analytics** from queries

## 📚 Next Steps

- **Extend the pipeline** with additional data sources
- **Add real-time alerting** with CloudWatch alarms
- **Create dashboards** with Amazon QuickSight
- **Implement ML models** for player behavior prediction
- **Add data retention policies** for cost optimization

This complete setup demonstrates modern data engineering practices using a fun, relatable Minecraft server as the data source! 