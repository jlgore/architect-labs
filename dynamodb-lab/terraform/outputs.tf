output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.students_table.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.students_table.arn
}

output "email_index_name" {
  description = "Name of the Email GSI"
  value       = "EmailIndex"
} 