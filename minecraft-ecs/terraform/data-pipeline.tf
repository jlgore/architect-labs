# Data Pipeline Infrastructure for Minecraft Analytics

# S3 Buckets for data storage
resource "aws_s3_bucket" "minecraft_data_lake" {
  bucket = "minecraft-data-lake-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "minecraft-data-lake"
    Environment = var.environment
    Purpose     = "Data Lake for Minecraft Analytics"
  }
}

resource "aws_s3_bucket" "minecraft_logs" {
  bucket = "minecraft-logs-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "minecraft-logs"
    Environment = var.environment
    Purpose     = "Raw logs storage"
  }
}

resource "aws_s3_bucket" "glue_scripts" {
  bucket = "minecraft-glue-scripts-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "minecraft-glue-scripts"
    Environment = var.environment
    Purpose     = "Glue job scripts storage"
  }
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "minecraft_data_lake" {
  bucket = aws_s3_bucket.minecraft_data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "minecraft_logs" {
  bucket = aws_s3_bucket.minecraft_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "minecraft_data_lake" {
  bucket = aws_s3_bucket.minecraft_data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "minecraft_logs" {
  bucket = aws_s3_bucket.minecraft_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "minecraft_data_lake" {
  bucket = aws_s3_bucket.minecraft_data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "minecraft_logs" {
  bucket = aws_s3_bucket.minecraft_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VPC Flow Logs
resource "aws_flow_log" "minecraft_vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.minecraft_vpc.id

  tags = {
    Name = "minecraft-vpc-flow-logs"
  }
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs"
  retention_in_days = 7

  tags = {
    Name        = "minecraft-vpc-flow-logs"
    Environment = var.environment
  }
}

# Kinesis Data Firehose for streaming logs to S3
resource "aws_kinesis_firehose_delivery_stream" "minecraft_logs_stream" {
  name        = "minecraft-logs-stream"
  destination = "s3"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.minecraft_logs.arn
    prefix             = "minecraft-container-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/"
    buffer_size        = 5
    buffer_interval    = 300
    compression_format = "GZIP"
  }

  tags = {
    Name        = "minecraft-logs-stream"
    Environment = var.environment
  }
}

# Kinesis Data Firehose for VPC Flow Logs
resource "aws_kinesis_firehose_delivery_stream" "vpc_flow_logs_stream" {
  name        = "vpc-flow-logs-stream"
  destination = "s3"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.minecraft_logs.arn
    prefix             = "vpc-flow-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "vpc-errors/"
    buffer_size        = 5
    buffer_interval    = 300
    compression_format = "GZIP"
  }

  tags = {
    Name        = "vpc-flow-logs-stream"
    Environment = var.environment
  }
}

# CloudWatch Logs Subscription Filter for Minecraft container logs
resource "aws_cloudwatch_log_subscription_filter" "minecraft_logs_filter" {
  name            = "minecraft-logs-filter"
  log_group_name  = aws_cloudwatch_log_group.minecraft_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.minecraft_logs_stream.arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn
}

# CloudWatch Logs Subscription Filter for VPC Flow Logs
resource "aws_cloudwatch_log_subscription_filter" "vpc_flow_logs_filter" {
  name            = "vpc-flow-logs-filter"
  log_group_name  = aws_cloudwatch_log_group.vpc_flow_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.vpc_flow_logs_stream.arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn
}

# Glue Database
resource "aws_glue_catalog_database" "minecraft_analytics" {
  name = "minecraft_analytics"

  description = "Database for Minecraft server analytics"
}

# Glue Crawler for Minecraft logs
resource "aws_glue_crawler" "minecraft_logs_crawler" {
  database_name = aws_glue_catalog_database.minecraft_analytics.name
  name          = "minecraft-logs-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.minecraft_logs.bucket}/minecraft-container-logs/"
  }

  tags = {
    Name        = "minecraft-logs-crawler"
    Environment = var.environment
  }
}

# Glue Crawler for VPC Flow Logs
resource "aws_glue_crawler" "vpc_flow_logs_crawler" {
  database_name = aws_glue_catalog_database.minecraft_analytics.name
  name          = "vpc-flow-logs-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.minecraft_logs.bucket}/vpc-flow-logs/"
  }

  tags = {
    Name        = "vpc-flow-logs-crawler"
    Environment = var.environment
  }
} 