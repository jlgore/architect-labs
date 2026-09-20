output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "ec2_sg_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

output "efs_sg_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs_sg.id
}

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.main.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.main.dns_name
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.efs_client.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.efs_client.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip}"
}

output "efs_write_test_command" {
  description = "Command to write a test file to EFS via SSH"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'echo \"Test data from $(hostname) at $(date)\" > /mnt/efs/test-file.txt'"
}

output "efs_read_test_command" {
  description = "Command to read files from EFS via SSH"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'cat /mnt/efs/test-file.txt'"
}

output "efs_list_command" {
  description = "Command to list all files in EFS via SSH"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'ls -lah /mnt/efs'"
}

output "efs_mount_verification" {
  description = "Command to verify EFS is mounted"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'df -h | grep efs'"
}

output "demo_instructions" {
  description = "Quick demo instructions"
  value       = <<-EOT

    === EC2 + EFS Lab Demo Instructions ===

    1. Connect to EC2:
       ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip}

    2. Verify EFS is mounted:
       ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'df -h | grep efs'

    3. List files in EFS:
       ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'ls -lah /mnt/efs'

    4. Write to EFS:
       ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'echo "Test data from $(hostname) at $(date)" > /mnt/efs/test-file.txt'

    5. Read from EFS:
       ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.efs_client.public_ip} 'cat /mnt/efs/test-file.txt'

    6. Once connected via SSH, you can also run:
       - echo "Hello EFS" > /mnt/efs/myfile.txt
       - cat /mnt/efs/myfile.txt
       - ls -la /mnt/efs/

    EFS ID: ${aws_efs_file_system.main.id}

  EOT
}
