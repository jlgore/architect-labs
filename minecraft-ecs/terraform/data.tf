data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Outputs for reference
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.minecraft_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.minecraft_sg.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.minecraft_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.minecraft_service.name
}

# Data Pipeline Outputs
output "data_lake_bucket" {
  description = "S3 bucket for processed data lake"
  value       = aws_s3_bucket.minecraft_data_lake.bucket
}

output "logs_bucket" {
  description = "S3 bucket for raw logs"
  value       = aws_s3_bucket.minecraft_logs.bucket
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.bucket
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.minecraft_analytics.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.minecraft_analytics.name
}

output "minecraft_log_processor_job" {
  description = "Name of the Minecraft log processor Glue job"
  value       = aws_glue_job.minecraft_log_processor.name
}

output "vpc_flow_log_processor_job" {
  description = "Name of the VPC Flow Log processor Glue job"
  value       = aws_glue_job.vpc_flow_log_processor.name
}
