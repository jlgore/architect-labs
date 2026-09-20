# Minecraft Data Pipeline on AWS

This project demonstrates a comprehensive data pipeline using your Minecraft ECS server as the data source. The pipeline captures both application logs (Minecraft server logs) and infrastructure logs (VPC Flow Logs), processes them with AWS Glue, and provides analytics through Amazon Athena.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Minecraft     │    │   VPC Flow       │    │   CloudWatch    │
│   ECS Server    │    │   Logs           │    │   Logs          │
└─────────┬───────┘    └─────────┬────────┘    └─────────┬───────┘
          │                      │                       │
          │                      │                       │
          ▼                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kinesis Data Firehose                       │
│              (Streaming to S3 with compression)                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      S3 Raw Logs                               │
│         minecraft-container-logs/  |  vpc-flow-logs/           │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Glue Jobs                              │
│    minecraft_log_processor.py  |  vpc_flow_log_processor.py    │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   S3 Data Lake                                 │
│  minecraft-events/ | player-statistics/ | network-statistics/ │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Amazon Athena + Glue Catalog                      │
│                   (SQL Analytics)                              │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Data Sources
- **Minecraft Server Logs**: Application logs from the ECS container
- **VPC Flow Logs**: Network traffic logs from the VPC

### 2. Data Ingestion
- **Kinesis Data Firehose**: Streams logs from CloudWatch to S3
- **CloudWatch Logs**: Centralized logging service
- **S3 Raw Storage**: Compressed storage with time-based partitioning

### 3. Data Processing
- **AWS Glue Jobs**: Spark-based ETL jobs that run hourly
- **Glue Crawlers**: Automatically discover and catalog data schemas
- **Glue Catalog**: Metadata repository for data discovery

### 4. Data Analytics
- **Amazon Athena**: Serverless SQL query engine
- **Pre-built Queries**: Common analytics queries for immediate insights

## Analytics Capabilities

### Player Analytics
- **Death Statistics**: Track how many times each player has died
- **Session Analysis**: Login/logout patterns and session duration
- **Achievement Tracking**: Monitor player progression
- **Chat Activity**: Measure player engagement through chat messages

### Server Analytics
- **Overall Activity**: Total events, unique players, server uptime
- **Performance Metrics**: Server starts/stops, world saves
- **Player Engagement**: Death rates, achievement rates

### Network Analytics
- **Traffic Analysis**: Minecraft-specific vs. total network traffic
- **Connection Patterns**: Source IPs, connection duration, success rates
- **Geographic Distribution**: Basic IP-based geographic analysis
- **Security Insights**: Failed connections, potential threats

## Deployment

1. **Deploy the Infrastructure**:
   ```bash
   cd minecraft-ecs/terraform
   terraform init
   terraform plan
   terraform apply
   ```

2. **Wait for Data Collection**:
   - VPC Flow Logs start immediately
   - Minecraft logs begin when players connect
   - Glue jobs run hourly to process data

3. **Access Analytics**:
   - Open Amazon Athena in the AWS Console
   - Select the `minecraft-analytics` workgroup
   - Use the pre-built named queries or write custom SQL

## Sample Queries

### Top Players by Death Count
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
LIMIT 10;
```

### Hourly Player Activity
```sql
SELECT 
    year, month, day, hour,
    COUNT(DISTINCT CASE WHEN event_type = 'player_join' THEN player_name END) as unique_logins,
    COUNT(CASE WHEN event_type = 'player_death' THEN 1 END) as total_deaths,
    COUNT(CASE WHEN event_type = 'player_achievement' THEN 1 END) as total_achievements
FROM minecraft_events
WHERE year = '2024' AND month = '12'
GROUP BY year, month, day, hour
ORDER BY year DESC, month DESC, day DESC, hour DESC;
```

### Network Traffic Analysis
```sql
SELECT 
    srcaddr as source_ip,
    traffic_type,
    connection_count,
    total_bytes,
    success_rate,
    connection_duration_hours
FROM connection_statistics
WHERE traffic_type = 'minecraft'
ORDER BY connection_count DESC
LIMIT 20;
```

## Data Pipeline Features

### Real-time Processing
- Logs are streamed to S3 within 5 minutes via Kinesis Firehose
- Glue jobs process data hourly for near real-time analytics
- EventBridge triggers ensure consistent processing

### Cost Optimization
- S3 storage with compression (GZIP)
- Partitioned data for efficient querying
- Glue jobs use minimal resources (G.1X workers)
- Athena charges only for data scanned

### Scalability
- Serverless architecture scales automatically
- Partitioned storage supports years of data
- Glue jobs can be scaled up for larger datasets

### Security
- All S3 buckets encrypted at rest
- IAM roles with least privilege access
- VPC Flow Logs capture security events
- No public access to data buckets

## Monitoring and Troubleshooting

### CloudWatch Metrics
- Glue job execution metrics
- Kinesis Firehose delivery metrics
- Athena query performance

### Logs
- Glue job logs in CloudWatch
- Firehose error logs for failed deliveries
- VPC Flow Logs for network troubleshooting

### Common Issues
1. **No data in Athena**: Check if Glue crawlers have run and discovered tables
2. **Glue job failures**: Check CloudWatch logs for the specific job
3. **Missing partitions**: Run Glue crawlers to discover new partitions

## Cost Estimation

For a typical small Minecraft server (10-50 players):
- **S3 Storage**: ~$5-10/month for logs and processed data
- **Glue Jobs**: ~$10-20/month for hourly processing
- **Athena Queries**: ~$5-15/month depending on query frequency
- **Other Services**: ~$5-10/month (Kinesis, CloudWatch, etc.)

**Total Estimated Cost**: $25-55/month

## Extending the Pipeline

### Additional Data Sources
- Add more log sources (web server logs, database logs)
- Integrate with external APIs (weather, game events)
- Include real-time player location tracking

### Advanced Analytics
- Machine learning models for player behavior prediction
- Real-time alerting for server issues
- Automated player engagement scoring

### Visualization
- Connect to Amazon QuickSight for dashboards
- Build custom web applications using the data
- Create real-time monitoring displays

## Security Considerations

### Data Privacy
- Player data is anonymized where possible
- Implement data retention policies
- Consider GDPR compliance for EU players

### Access Control
- Use IAM roles for service-to-service access
- Implement least privilege principles
- Monitor access with CloudTrail

### Network Security
- VPC Flow Logs help identify security threats
- Monitor for unusual connection patterns
- Implement automated alerting for security events

This data pipeline provides a solid foundation for understanding your Minecraft server's usage patterns, player behavior, and network characteristics while demonstrating modern AWS data engineering practices. 