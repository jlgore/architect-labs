# AWS Glue Jobs for Data Processing

# Upload Glue script for Minecraft log processing
resource "aws_s3_object" "minecraft_log_processor_script" {
  bucket = aws_s3_bucket.glue_scripts.bucket
  key    = "scripts/minecraft_log_processor.py"
  content = templatefile("${path.module}/glue_scripts/minecraft_log_processor.py", {
    output_bucket = aws_s3_bucket.minecraft_data_lake.bucket
    database_name = aws_glue_catalog_database.minecraft_analytics.name
  })
  content_type = "text/plain"

  tags = {
    Name        = "minecraft-log-processor-script"
    Environment = var.environment
  }
}

# Upload Glue script for VPC Flow Log processing
resource "aws_s3_object" "vpc_flow_log_processor_script" {
  bucket = aws_s3_bucket.glue_scripts.bucket
  key    = "scripts/vpc_flow_log_processor.py"
  content = templatefile("${path.module}/glue_scripts/vpc_flow_log_processor.py", {
    output_bucket = aws_s3_bucket.minecraft_data_lake.bucket
    database_name = aws_glue_catalog_database.minecraft_analytics.name
  })
  content_type = "text/plain"

  tags = {
    Name        = "vpc-flow-log-processor-script"
    Environment = var.environment
  }
}

# Glue Job for processing Minecraft logs
resource "aws_glue_job" "minecraft_log_processor" {
  name         = "minecraft-log-processor"
  role_arn     = aws_iam_role.glue_role.arn
  glue_version = "4.0"

  command {
    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/scripts/minecraft_log_processor.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.glue_scripts.bucket}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_scripts.bucket}/temp/"
    "--source_bucket"                    = aws_s3_bucket.minecraft_logs.bucket
    "--output_bucket"                    = aws_s3_bucket.minecraft_data_lake.bucket
    "--database_name"                    = aws_glue_catalog_database.minecraft_analytics.name
  }

  max_retries = 1
  timeout     = 60
  worker_type = "G.1X"
  number_of_workers = 2

  tags = {
    Name        = "minecraft-log-processor"
    Environment = var.environment
  }
}

# Glue Job for processing VPC Flow Logs
resource "aws_glue_job" "vpc_flow_log_processor" {
  name         = "vpc-flow-log-processor"
  role_arn     = aws_iam_role.glue_role.arn
  glue_version = "4.0"

  command {
    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/scripts/vpc_flow_log_processor.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.glue_scripts.bucket}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_scripts.bucket}/temp/"
    "--source_bucket"                    = aws_s3_bucket.minecraft_logs.bucket
    "--output_bucket"                    = aws_s3_bucket.minecraft_data_lake.bucket
    "--database_name"                    = aws_glue_catalog_database.minecraft_analytics.name
  }

  max_retries = 1
  timeout     = 60
  worker_type = "G.1X"
  number_of_workers = 2

  tags = {
    Name        = "vpc-flow-log-processor"
    Environment = var.environment
  }
}

# EventBridge rule to trigger Glue jobs periodically
resource "aws_cloudwatch_event_rule" "glue_job_schedule" {
  name                = "minecraft-glue-job-schedule"
  description         = "Trigger Glue jobs every hour"
  schedule_expression = "rate(1 hour)"

  tags = {
    Name        = "minecraft-glue-job-schedule"
    Environment = var.environment
  }
}

# Lambda function to trigger Minecraft log processor
resource "aws_lambda_function" "trigger_minecraft_glue_job" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "trigger-minecraft-glue-job"
  role            = aws_iam_role.lambda_glue_trigger_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.minecraft_log_processor.name
    }
  }

  tags = {
    Name        = "trigger-minecraft-glue-job"
    Environment = var.environment
  }

  depends_on = [data.archive_file.lambda_zip]
}

# Lambda function to trigger VPC Flow log processor
resource "aws_lambda_function" "trigger_vpc_glue_job" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "trigger-vpc-glue-job"
  role            = aws_iam_role.lambda_glue_trigger_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.vpc_flow_log_processor.name
    }
  }

  tags = {
    Name        = "trigger-vpc-glue-job"
    Environment = var.environment
  }

  depends_on = [data.archive_file.lambda_zip]
}

# Create the Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "trigger_glue_job.zip"
  source {
    content = <<EOF
import boto3
import os
import json

def handler(event, context):
    glue_client = boto3.client('glue')
    job_name = os.environ['GLUE_JOB_NAME']
    
    try:
        response = glue_client.start_job_run(JobName=job_name)
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully started Glue job: {job_name}',
                'jobRunId': response['JobRunId']
            })
        }
    except Exception as e:
        print(f'Error starting Glue job {job_name}: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error starting Glue job: {str(e)}'
            })
        }
EOF
    filename = "index.py"
  }
}

# IAM role for Lambda to trigger Glue jobs
resource "aws_iam_role" "lambda_glue_trigger_role" {
  name = "minecraft-lambda-glue-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "minecraft-lambda-glue-trigger-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_glue_trigger_policy" {
  name = "minecraft-lambda-glue-trigger-policy"
  role = aws_iam_role.lambda_glue_trigger_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns"
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/${aws_glue_job.minecraft_log_processor.name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/${aws_glue_job.vpc_flow_log_processor.name}"
        ]
      }
    ]
  })
}

# EventBridge target for Minecraft log processor Lambda
resource "aws_cloudwatch_event_target" "minecraft_log_processor_target" {
  rule      = aws_cloudwatch_event_rule.glue_job_schedule.name
  target_id = "MinecraftLogProcessorTarget"
  arn       = aws_lambda_function.trigger_minecraft_glue_job.arn
}

# EventBridge target for VPC Flow log processor Lambda
resource "aws_cloudwatch_event_target" "vpc_flow_log_processor_target" {
  rule      = aws_cloudwatch_event_rule.glue_job_schedule.name
  target_id = "VPCFlowLogProcessorTarget"
  arn       = aws_lambda_function.trigger_vpc_glue_job.arn
}

# Lambda permissions for EventBridge to invoke the functions
resource "aws_lambda_permission" "allow_eventbridge_minecraft" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_minecraft_glue_job.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.glue_job_schedule.arn
}

resource "aws_lambda_permission" "allow_eventbridge_vpc" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_vpc_glue_job.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.glue_job_schedule.arn
} 