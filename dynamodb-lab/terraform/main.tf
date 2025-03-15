provider "aws" {
  region = var.aws_region
}

resource "aws_dynamodb_table" "students_table" {
  name         = "Students"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "StudentID"
  range_key    = "CourseID"

  attribute {
    name = "StudentID"
    type = "S"
  }

  attribute {
    name = "CourseID"
    type = "S"
  }

  attribute {
    name = "Email"
    type = "S"
  }

  global_secondary_index {
    name               = "EmailIndex"
    hash_key           = "Email"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "students-table"
    Environment = "Lab"
    Project     = "DynamoDB-Lab"
  }
} 