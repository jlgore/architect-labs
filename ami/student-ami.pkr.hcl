packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "student-ami" {
  ami_name      = "student-lab-environment-al2023-{{timestamp}}"
  instance_type = "t2.micro" // Using a supported instance type in the sandbox
  region        = "us-east-1" // Use the sandbox region
  
  // Use Amazon Linux 2023 AMI
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-kernel-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  
  // Alternatively, you can use the SSM parameter directly
  // source_ami_from_ssm_parameter = "/aws/service/al2023-ami-kernel-default-x86_64"
  
  ssh_username = "ec2-user"
  
  ami_groups    = ["all"]  // This makes the AMI publicly accessible
  
  ami_description = "Student lab environment with pre-installed development tools based on Amazon Linux 2023"
  
  tags = {
    Name        = "StudentLabEnvironment-AL2023"
    Environment = "Education"
    Project     = "AWS Academy"
  }
}

build {
  name    = "student-lab-environment-al2023"
  sources = ["source.amazon-ebs.student-ami"]
  
  provisioner "shell" {
    inline = [
      "echo Installing development tools...",
      "sudo dnf update -y",
      "sudo dnf install -y git jq wget unzip vim tar gzip"
    ]
  }
  
  // Install Terraform
  provisioner "shell" {
    inline = [
      "echo Installing Terraform...",
      "sudo dnf install -y dnf-plugins-core",
      "sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo",
      "sudo dnf -y install terraform"
    ]
  }
  
  // Install Packer
  provisioner "shell" {
    inline = [
      "echo Installing Packer...",
      "sudo dnf -y install packer"
    ]
  }
  
  // Install AWS CLI v2
  provisioner "shell" {
    inline = [
      "echo Installing AWS CLI v2...",
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "rm -rf aws awscliv2.zip"
    ]
  }
  
  // Install MySQL client for RDS lab
  provisioner "shell" {
    inline = [
      "echo Installing MySQL client...",
      "sudo dnf install -y mariadb105"
    ]
  }
  
  // Clone your lab repository
  provisioner "shell" {
    inline = [
      "echo Cloning lab repository...",
      "git clone https://github.com/jlgore/architect-labs.git /home/ec2-user/architect-labs",
      "sudo chown -R ec2-user:ec2-user /home/ec2-user/architect-labs"
    ]
  }
  
  // Add any additional setup scripts or configurations
  provisioner "shell" {
    inline = [
      "echo Setting up environment variables...",
      "echo 'export PATH=$PATH:/usr/local/bin' >> /home/ec2-user/.bashrc",
      "echo 'alias tf=terraform' >> /home/ec2-user/.bashrc",
      
      // Create a validation script
      "cat > /home/ec2-user/validate-environment.sh << 'EOF'",
      "#!/bin/bash",
      "echo \"Validating environment...\"",
      "echo \"Terraform version: $(terraform --version)\"",
      "echo \"Packer version: $(packer --version)\"",
      "echo \"AWS CLI version: $(aws --version)\"",
      "echo \"MySQL client version: $(mysql --version)\"",
      "echo \"Repository status: $(cd ~/architect-labs && git status)\"",
      "echo \"Environment validation complete!\"",
      "EOF",
      "chmod +x /home/ec2-user/validate-environment.sh",
      "sudo chown ec2-user:ec2-user /home/ec2-user/validate-environment.sh"
    ]
  }
  
  // Create a welcome message
  provisioner "shell" {
    inline = [
      "echo 'Creating welcome message...'",
      "sudo tee /etc/motd > /dev/null << 'EOF'",
      "===============================================",
      "  ZIYOTEK INSTITUTE | Cloud Architecting Lab Environment",
      "  ",
      "  Pre-installed tools:",
      "  - Terraform, Packer, AWS CLI v2, MySQL client",
      "  - Git and other development utilities",
      "  ",
      "  For Ziyotek Students only!!",
      "  ",
      "  Run ./validate-environment.sh to verify setup",
      "===============================================",
      "EOF"
    ]
  }
  
  // Install code-server (VS Code in the browser) and set up the service
  provisioner "shell" {
    inline = [
      "echo Installing code-server...",
      "curl -fsSL https://code-server.dev/install.sh | sh",
      
      // Configure code-server with custom settings
      "mkdir -p ~/.config/code-server/",
      "cat > ~/.config/code-server/config.yaml << 'EOF'",
      "bind-addr: 0.0.0.0:8080",
      "auth: password",
      "password: studentpassword",
      "cert: false",
      "EOF",
      
      // Enable and start the service using the recommended approach
      "sudo systemctl enable --now code-server@ec2-user",
      
      // Verify the service is running
      "sudo systemctl status code-server@ec2-user",
      
      // Create a welcome file with instructions
      "mkdir -p ~/code-server-welcome",
      "cat > ~/code-server-welcome/README.md << 'EOF'",
      "# Welcome to code-server",
      "",
      "This is VS Code running in your browser. You can use it to edit files, run terminals, and more.",
      "",
      "## Access Information",
      "",
      "- **URL**: http://YOUR_INSTANCE_IP:8080",
      "- **Password**: studentpassword",
      "",
      "## Getting Started",
      "",
      "1. Open a terminal (Terminal > New Terminal)",
      "2. Navigate to the lab repository: `cd ~/architect-labs`",
      "3. Start working on your lab assignments",
      "",
      "## Important Security Note",
      "",
      "This is a development environment for educational purposes. The default password",
      "should be changed for any extended use. You can change it by modifying the",
      "password field in `~/.config/code-server/config.yaml`",
      "and restarting the service with `sudo systemctl restart code-server@ec2-user`.",
      "EOF"
    ]
  }
}