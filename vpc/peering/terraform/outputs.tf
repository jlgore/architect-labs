output "vpc_a_id" {
  description = "ID of VPC A"
  value       = aws_vpc.vpc_a.id
}

output "vpc_b_id" {
  description = "ID of VPC B"
  value       = aws_vpc.vpc_b.id
}

output "peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.peer.id
}

output "instance_a_public_ip" {
  description = "Public IP address of Instance A"
  value       = aws_instance.instance_a.public_ip
}

output "instance_a_private_ip" {
  description = "Private IP address of Instance A"
  value       = aws_instance.instance_a.private_ip
}

output "instance_b_public_ip" {
  description = "Public IP address of Instance B"
  value       = aws_instance.instance_b.public_ip
}

output "instance_b_private_ip" {
  description = "Private IP address of Instance B"
  value       = aws_instance.instance_b.private_ip
}

output "connectivity_test_command" {
  description = "Command to test connectivity between instances"
  value       = "ssh -i labsuser.pem ec2-user@${aws_instance.instance_a.public_ip} 'ping -c 4 ${aws_instance.instance_b.private_ip}'"
} 