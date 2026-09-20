# Amazon Athena Configuration for Data Analytics

# S3 bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "minecraft-athena-results-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "minecraft-athena-results"
    Environment = var.environment
    Purpose     = "Athena query results storage"
  }
}

resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Minecraft Analytics Workgroup
resource "aws_athena_workgroup" "minecraft_analytics" {
  name = "minecraft-analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Name        = "minecraft-analytics"
    Environment = var.environment
  }
}

# Athena Named Queries for common analytics
resource "aws_athena_named_query" "player_death_statistics" {
  name      = "player-death-statistics"
  database  = aws_glue_catalog_database.minecraft_analytics.name
  workgroup = aws_athena_workgroup.minecraft_analytics.id
  query     = <<EOF
SELECT 
    player_name,
    death_count,
    login_count,
    CASE 
        WHEN login_count > 0 THEN CAST(death_count AS DOUBLE) / CAST(login_count AS DOUBLE)
        ELSE 0 
    END as deaths_per_session,
    achievement_count,
    chat_message_count,
    first_seen,
    last_seen,
    stats_calculated_at
FROM player_statistics
WHERE player_name IS NOT NULL
ORDER BY death_count DESC
LIMIT 20;
EOF

  description = "Top 20 players by death count with death-to-session ratio"
}

resource "aws_athena_named_query" "server_activity_summary" {
  name      = "server-activity-summary"
  database  = aws_glue_catalog_database.minecraft_analytics.name
  workgroup = aws_athena_workgroup.minecraft_analytics.id
  query     = <<EOF
SELECT 
    total_events,
    unique_players,
    total_logins,
    total_logouts,
    total_deaths,
    total_achievements,
    total_chat_messages,
    server_starts,
    server_stops,
    CASE 
        WHEN total_logins > 0 THEN CAST(total_deaths AS DOUBLE) / CAST(total_logins AS DOUBLE)
        ELSE 0 
    END as overall_death_rate,
    earliest_event,
    latest_event,
    stats_calculated_at
FROM server_statistics
ORDER BY stats_calculated_at DESC
LIMIT 1;
EOF

  description = "Latest server activity summary with overall death rate"
}

resource "aws_athena_named_query" "network_traffic_analysis" {
  name      = "network-traffic-analysis"
  database  = aws_glue_catalog_database.minecraft_analytics.name
  workgroup = aws_athena_workgroup.minecraft_analytics.id
  query     = <<EOF
SELECT 
    total_flows,
    total_packets,
    total_bytes,
    unique_source_ips,
    unique_dest_ips,
    accepted_flows,
    rejected_flows,
    minecraft_flows,
    minecraft_packets,
    minecraft_bytes,
    minecraft_unique_source_ips,
    CASE 
        WHEN total_flows > 0 THEN CAST(minecraft_flows AS DOUBLE) / CAST(total_flows AS DOUBLE) * 100
        ELSE 0 
    END as minecraft_traffic_percentage,
    CASE 
        WHEN accepted_flows + rejected_flows > 0 THEN CAST(accepted_flows AS DOUBLE) / CAST(accepted_flows + rejected_flows AS DOUBLE) * 100
        ELSE 0 
    END as acceptance_rate,
    stats_calculated_at
FROM network_statistics
ORDER BY stats_calculated_at DESC
LIMIT 1;
EOF

  description = "Network traffic analysis with Minecraft traffic percentage"
}

resource "aws_athena_named_query" "top_minecraft_connections" {
  name      = "top-minecraft-connections"
  database  = aws_glue_catalog_database.minecraft_analytics.name
  workgroup = aws_athena_workgroup.minecraft_analytics.id
  query     = <<EOF
SELECT 
    srcaddr as source_ip,
    traffic_type,
    connection_count,
    total_packets,
    total_bytes,
    avg_packets_per_flow,
    avg_bytes_per_flow,
    connection_duration_hours,
    successful_connections,
    failed_connections,
    success_rate,
    first_connection,
    last_connection
FROM connection_statistics
WHERE traffic_type IN ('minecraft', 'servertap')
ORDER BY connection_count DESC
LIMIT 20;
EOF

  description = "Top 20 source IPs by connection count to Minecraft services"
}

resource "aws_athena_named_query" "hourly_player_activity" {
  name      = "hourly-player-activity"
  database  = aws_glue_catalog_database.minecraft_analytics.name
  workgroup = aws_athena_workgroup.minecraft_analytics.id
  query     = <<EOF
SELECT 
    year,
    month,
    day,
    hour,
    COUNT(DISTINCT CASE WHEN event_type = 'player_join' THEN player_name END) as unique_logins,
    COUNT(CASE WHEN event_type = 'player_death' THEN 1 END) as total_deaths,
    COUNT(CASE WHEN event_type = 'player_achievement' THEN 1 END) as total_achievements,
    COUNT(CASE WHEN event_type = 'chat_message' THEN 1 END) as total_chat_messages,
    COUNT(*) as total_events
FROM minecraft_events
WHERE year IS NOT NULL AND month IS NOT NULL AND day IS NOT NULL AND hour IS NOT NULL
GROUP BY year, month, day, hour
ORDER BY year DESC, month DESC, day DESC, hour DESC
LIMIT 24;
EOF

  description = "Hourly breakdown of player activity for the last 24 hours"
}

resource "aws_athena_named_query" "geographic_connection_analysis" {
  name      = "geographic-connection-analysis"
  database  = aws_glue_catalog_database.minecraft_analytics.name
  workgroup = aws_athena_workgroup.minecraft_analytics.id
  query     = <<EOF
SELECT 
    ip_class_a,
    ip_class_b,
    traffic_type,
    connection_count,
    unique_ips,
    total_packets,
    total_bytes,
    avg_packets,
    avg_bytes,
    CASE 
        WHEN ip_class_a = '10' THEN 'Private Network (RFC 1918)'
        WHEN ip_class_a = '172' AND CAST(SPLIT_PART(ip_class_b, '.', 2) AS INTEGER) BETWEEN 16 AND 31 THEN 'Private Network (RFC 1918)'
        WHEN ip_class_a = '192' AND ip_class_b = '192.168' THEN 'Private Network (RFC 1918)'
        WHEN ip_class_a = '127' THEN 'Localhost'
        ELSE 'Public Internet'
    END as network_type
FROM geographic_statistics
ORDER BY connection_count DESC
LIMIT 50;
EOF

  description = "Geographic analysis of connections with network type classification"
}

# Create Glue tables for the processed data
resource "aws_glue_catalog_table" "minecraft_events" {
  name          = "minecraft_events"
  database_name = aws_glue_catalog_database.minecraft_analytics.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "projection.enabled"  = "true"
    "projection.year.type" = "integer"
    "projection.year.range" = "2020,2030"
    "projection.month.type" = "integer"
    "projection.month.range" = "01,12"
    "projection.month.digits" = "2"
    "projection.day.type" = "integer"
    "projection.day.range" = "01,31"
    "projection.day.digits" = "2"
    "projection.hour.type" = "integer"
    "projection.hour.range" = "00,23"
    "projection.hour.digits" = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.minecraft_data_lake.bucket}/processed-data/minecraft-events/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.minecraft_data_lake.bucket}/processed-data/minecraft-events/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }
    columns {
      name = "event_type"
      type = "string"
    }
    columns {
      name = "player_name"
      type = "string"
    }
    columns {
      name = "message"
      type = "string"
    }
    columns {
      name = "server_info"
      type = "string"
    }
    columns {
      name = "coordinates"
      type = "string"
    }
    columns {
      name = "dimension"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
} 