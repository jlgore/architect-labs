# Lambda Layer for psycopg2
resource "aws_lambda_layer_version" "psycopg2_layer" {
  filename         = "psycopg2-layer.zip"
  layer_name       = "psycopg2-layer"
  description      = "psycopg2 library for Lambda"
  
  compatible_runtimes = ["python3.10"]
  
  # Create the layer zip file
  depends_on = [null_resource.create_psycopg2_layer]
}

# Create psycopg2 layer
resource "null_resource" "create_psycopg2_layer" {
  triggers = {
    # Force rebuild when we change this
    python_version = "3.10-fixed"
  }
  
  provisioner "local-exec" {
    command = <<EOF
      # The zip file should already exist from Docker creation
      echo "Using Docker-created psycopg2-layer.zip for Python 3.10"
EOF
  }
}

# Store Service Lambda
module "store_service" {
  source = "./modules/lambda"
  
  function_name = "StoreServiceLambda"
  description   = "Manages store information"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  
  # Required parameters
  source_path        = "${path.module}/lambda_functions/store_service"
  execution_role_arn = aws_iam_role.lambda_exec.arn
  timeout           = 30
  memory_size       = 256
  
  # Add the psycopg2 layer
  layers = [aws_lambda_layer_version.psycopg2_layer.arn]
  
  environment_variables = {
    DB_HOST     = aws_db_instance.quickmart.address
    DB_PORT     = tostring(aws_db_instance.quickmart.port)
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
    DB_PASSWORD = aws_ssm_parameter.db_password.value
  }
  
  tags = {
    Environment = var.environment
    Service     = "StoreService"
  }
}

# Inventory Service Lambda
module "inventory_service" {
  source = "./modules/lambda"
  
  function_name = "InventoryServiceLambda"
  description   = "Manages product inventory per store"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  
  # Required parameters
  source_path        = "${path.module}/lambda_functions/inventory_service"
  execution_role_arn = aws_iam_role.lambda_exec.arn
  timeout           = 30
  memory_size       = 256
  
  # Add the psycopg2 layer
  layers = [aws_lambda_layer_version.psycopg2_layer.arn]
  
  environment_variables = {
    DB_HOST          = aws_db_instance.quickmart.address
    DB_PORT          = tostring(aws_db_instance.quickmart.port)
    DB_NAME          = var.db_name
    DB_USER          = var.db_username
    DB_PASSWORD      = aws_ssm_parameter.db_password.value
    STORE_SERVICE_URL = module.store_service.function_url
  }
  
  tags = {
    Environment = var.environment
    Service     = "InventoryService"
  }
  
  depends_on = [module.store_service]
}

# Gas Price Service Lambda
module "gas_price_service" {
  source = "./modules/lambda"
  
  function_name = "GasPriceServiceLambda"
  description   = "Manages gas prices per store"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  
  # Required parameters
  source_path        = "${path.module}/lambda_functions/gas_price_service"
  execution_role_arn = aws_iam_role.lambda_exec.arn
  timeout           = 30
  memory_size       = 256
  
  # Add the psycopg2 layer
  layers = [aws_lambda_layer_version.psycopg2_layer.arn]
  
  environment_variables = {
    DB_HOST          = aws_db_instance.quickmart.address
    DB_PORT          = tostring(aws_db_instance.quickmart.port)
    DB_NAME          = var.db_name
    DB_USER          = var.db_username
    DB_PASSWORD      = aws_ssm_parameter.db_password.value
    STORE_SERVICE_URL = module.store_service.function_url
  }
  
  tags = {
    Environment = var.environment
    Service     = "GasPriceService"
  }
  
  depends_on = [module.store_service]
}
