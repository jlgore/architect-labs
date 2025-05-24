variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "quickmartdb"
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  default     = "quickmartadmin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.7"
}

variable "db_storage_size" {
  description = "Storage size in GB"
  type        = number
  default     = 20
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 128
}
