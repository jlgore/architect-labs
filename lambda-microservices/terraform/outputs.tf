# RDS Outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.quickmart.endpoint
}

output "rds_username" {
  description = "The master username for the RDS instance"
  value       = aws_db_instance.quickmart.username
  sensitive   = true
}

output "rds_password" {
  description = "The master password for the RDS instance (stored in SSM Parameter Store)"
  value       = "The database password is stored in SSM Parameter Store at ${aws_ssm_parameter.db_password.name}"
  sensitive   = true
}

# Lambda Function URLs
output "store_service_url" {
  description = "URL for the Store Service Lambda function"
  value       = module.store_service.function_url
}

output "inventory_service_url" {
  description = "URL for the Inventory Service Lambda function"
  value       = module.inventory_service.function_url
}

output "gas_price_service_url" {
  description = "URL for the Gas Price Service Lambda function"
  value       = module.gas_price_service.function_url
}

# Security Group IDs
output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

# VPC and Subnet Information
output "vpc_id" {
  description = "ID of the default VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs in the default VPC"
  value       = data.aws_subnets.default.ids
}
