provider "aws" {
  region = "us-east-1"
}

# Security Group for Web Servers
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"

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

# EC2 Instances for Simple Routing
resource "aws_instance" "simple_server" {
  ami                    = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Simple Routing Server</h1><p>This is the simple routing server</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Simple-Routing-Server"
  }
}

# EC2 Instances for Failover Routing
resource "aws_instance" "primary_server" {
  ami                    = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Primary Server</h1><p>This is the primary server</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Primary-Server"
  }
}

resource "aws_instance" "secondary_server" {
  ami                    = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Secondary Server</h1><p>This is the secondary server</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Secondary-Server"
  }
}

# EC2 Instances for Geolocation Routing
resource "aws_instance" "north_america_server" {
  ami                    = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>North America Server</h1><p>This is the North America server</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "North-America-Server"
  }
}

resource "aws_instance" "europe_server" {
  ami                    = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Europe Server</h1><p>This is the Europe server</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Europe-Server"
  }
}

resource "aws_instance" "default_server" {
  ami                    = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Default Server</h1><p>This is the default server</p></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Default-Server"
  }
}

# Route 53 Zone
resource "aws_route53_zone" "demo" {
  name = var.subdomain
}

# Simple Routing
resource "aws_route53_record" "simple" {
  zone_id = aws_route53_zone.demo.zone_id
  name    = "simple"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.simple_server.public_ip]
}

# Failover Routing
resource "aws_route53_record" "primary" {
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
  fqdn              = aws_instance.primary_server.public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
}

resource "aws_route53_health_check" "secondary" {
  fqdn              = aws_instance.secondary_server.public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
}

# Geolocation Routing
resource "aws_route53_record" "north_america" {
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