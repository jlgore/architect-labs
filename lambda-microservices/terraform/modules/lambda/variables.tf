variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 128
}

variable "source_path" {
  description = "Path to the Lambda function source code directory"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the IAM role that Lambda assumes when it executes your function"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "A map of tags to assign to the Lambda function"
  type        = map(string)
  default     = {}
}

variable "vpc_subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}
