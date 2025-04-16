# Providers for different regions
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "ireland"
}

provider "aws" {
  region = "ap-southeast-1"
  alias  = "singapore"
}

# Security Groups for each region
resource "aws_security_group" "web_sg_virginia" {
  provider = aws.virginia
  name     = "web-sg-virginia"
  description = "Security group for web servers in Virginia"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg_ireland" {
  provider = aws.ireland
  name     = "web-sg-ireland"
  description = "Security group for web servers in Ireland"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg_singapore" {
  provider = aws.singapore
  name     = "web-sg-singapore"
  description = "Security group for web servers in Singapore"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances for Simple Routing (in Virginia)
resource "aws_instance" "simple_server" {
  provider = aws.virginia
  ami                    = data.aws_ssm_parameter.virginia_ami.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_virginia.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Simple Routing Server</h1><p>This is the simple routing server in Virginia</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Simple-Routing-Server"
  }
}

# EC2 Instances for Failover Routing (in Virginia)
resource "aws_instance" "primary_server" {
  provider = aws.virginia
  ami                    = data.aws_ssm_parameter.virginia_ami.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_virginia.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Primary Server</h1><p>This is the primary server in Virginia</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Primary-Server"
  }
}

resource "aws_instance" "secondary_server" {
  provider = aws.virginia
  ami                    = data.aws_ssm_parameter.virginia_ami.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_virginia.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Secondary Server</h1><p>This is the secondary server in Virginia</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Secondary-Server"
  }
}

# EC2 Instances for Geolocation Routing
resource "aws_instance" "north_america_server" {
  provider = aws.virginia
  ami                    = data.aws_ssm_parameter.virginia_ami.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_virginia.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>North America Server</h1><p>This is the North America server in Virginia</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "North-America-Server"
  }
}

resource "aws_instance" "europe_server" {
  provider = aws.ireland
  ami                    = data.aws_ssm_parameter.ireland_ami.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_ireland.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Europe Server</h1><p>This is the Europe server in Ireland</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Europe-Server"
  }
}

resource "aws_instance" "default_server" {
  provider = aws.singapore
  ami                    = data.aws_ssm_parameter.singapore_ami.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_singapore.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Default Server</h1><p>This is the default server in Singapore</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Default-Server"
  }
}

# Get the parent zone (example.com)
data "aws_route53_zone" "parent" {
  provider = aws.virginia
  name = var.parent_domain
}

# Create hosted zone for demo.example.com
resource "aws_route53_zone" "demo" {
  provider = aws.virginia
  name = var.subdomain
}

# Create NS records in the parent zone to delegate the subdomain
resource "aws_route53_record" "subdomain_ns" {
  provider = aws.virginia
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = var.subdomain
  type    = "NS"
  ttl     = "300"
  records = aws_route53_zone.demo.name_servers
}

# Simple Routing
resource "aws_route53_record" "simple" {
  provider = aws.virginia
  zone_id = aws_route53_zone.demo.zone_id
  name    = "simple"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.simple_server.public_ip]
}

# Failover Routing
resource "aws_route53_record" "primary" {
  provider = aws.virginia
  zone_id = aws_route53_zone.demo.zone_id
  name    = "failover"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.primary_server.public_ip]

  set_identifier = "primary"
  health_check_id = aws_route53_health_check.primary.id

  failover_routing_policy {
    type = "PRIMARY"
  }
}

resource "aws_route53_record" "secondary" {
  provider = aws.virginia
  zone_id = aws_route53_zone.demo.zone_id
  name    = "failover"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.secondary_server.public_ip]

  set_identifier = "secondary"
  health_check_id = aws_route53_health_check.secondary.id

  failover_routing_policy {
    type = "SECONDARY"
  }
}

# Health checks for failover routing
resource "aws_route53_health_check" "primary" {
  provider = aws.virginia
  fqdn              = aws_instance.primary_server.public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
}

resource "aws_route53_health_check" "secondary" {
  provider = aws.virginia
  fqdn              = aws_instance.secondary_server.public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
}

# Geolocation Routing
resource "aws_route53_record" "north_america" {
  provider = aws.virginia
  zone_id = aws_route53_zone.demo.zone_id
  name    = "geo"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.north_america_server.public_ip]

  set_identifier = "north-america"

  geolocation_routing_policy {
    continent = "NA"
  }
}

resource "aws_route53_record" "europe" {
  provider = aws.virginia
  zone_id = aws_route53_zone.demo.zone_id
  name    = "geo"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.europe_server.public_ip]

  set_identifier = "europe"

  geolocation_routing_policy {
    continent = "EU"
  }
}

resource "aws_route53_record" "default" {
  provider = aws.virginia
  zone_id = aws_route53_zone.demo.zone_id
  name    = "geo"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.default_server.public_ip]

  set_identifier = "default"

  geolocation_routing_policy {
    country = "*"
  }
}

# Get latest AMI IDs for each region
data "aws_ssm_parameter" "virginia_ami" {
  provider = aws.virginia
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "ireland_ami" {
  provider = aws.ireland
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "singapore_ami" {
  provider = aws.singapore
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Output variables to verify instance locations
output "simple_server" {
  value = {
    region    = "us-east-1 (Virginia)"
    public_ip = aws_instance.simple_server.public_ip
  }
}

output "primary_server" {
  value = {
    region    = "us-east-1 (Virginia)"
    public_ip = aws_instance.primary_server.public_ip
  }
}

output "secondary_server" {
  value = {
    region    = "us-east-1 (Virginia)"
    public_ip = aws_instance.secondary_server.public_ip
  }
}

output "north_america_server" {
  value = {
    region    = "us-east-1 (Virginia)"
    public_ip = aws_instance.north_america_server.public_ip
  }
}

output "europe_server" {
  value = {
    region    = "eu-west-1 (Ireland)"
    public_ip = aws_instance.europe_server.public_ip
  }
}

output "default_server" {
  value = {
    region    = "ap-southeast-1 (Singapore)"
    public_ip = aws_instance.default_server.public_ip
  }
}

# Output DNS endpoints for testing
output "dns_endpoints" {
  value = {
    simple    = "simple.${var.subdomain}"
    failover  = "failover.${var.subdomain}"
    geo       = "geo.${var.subdomain}"
  }
} 