# Package Lambda function source code
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/../../builds/${var.function_name}.zip"
  
  depends_on = [null_resource.pip_install]
}

# Install Python dependencies
resource "null_resource" "pip_install" {
  triggers = {
    requirements = fileexists("${var.source_path}/requirements.txt") ? file("${var.source_path}/requirements.txt") : ""
    lambda_code  = fileset(var.source_path, "**/*.py") != null ? join(",", fileset(var.source_path, "**/*.py")) : ""
  }

  provisioner "local-exec" {
    command = <<EOF
      if [ -f "${var.source_path}/requirements.txt" ]; then
        pip install -r ${var.source_path}/requirements.txt -t ${var.source_path} --upgrade
      fi
EOF
  }
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = var.execution_role_arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  # Use the packaged zip file
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  dynamic "environment" {
    for_each = length(keys(var.environment_variables)) > 0 ? [true] : []
    content {
      variables = var.environment_variables
    }
  }

  # VPC Configuration (optional)
  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [true] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tags = merge(
    {
      Name = var.function_name
    },
    var.tags
  )
}

# Lambda Function URL
resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"
}

# Outputs
output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_url" {
  description = "URL of the Lambda function"
  value       = aws_lambda_function_url.this.function_url
}
