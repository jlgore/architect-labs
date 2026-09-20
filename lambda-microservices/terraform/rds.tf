# RDS PostgreSQL Database
resource "aws_db_instance" "quickmart" {
  identifier = "qm-postgres-db"
  
  # Engine settings
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  
  # Storage settings
  allocated_storage     = var.db_storage_size
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  # Database settings
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432
  
  # Network settings
  db_subnet_group_name   = aws_db_subnet_group.quickmart.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true  # Changed to true so Lambda can connect from outside VPC
  
  # Backup settings
  backup_retention_period = 7
  backup_window          = "07:00-09:00"
  maintenance_window     = "sun:09:00-sun:11:00"
  
  # Other settings
  skip_final_snapshot = true
  deletion_protection = false
  multi_az           = false
  
  tags = {
    Name        = "qm-postgres-db"
    Environment = var.environment
  }
} 