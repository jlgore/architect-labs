# Route 53 Routing Demo Environment

This demo environment demonstrates three different Route 53 routing policies with actual web servers:

1. Simple Routing
2. Failover Routing
3. Geolocation Routing

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured
- Terraform installed
- A domain name that you can use for testing (or use the default demo.example.com)

## Architecture

The demo creates:

1. **Simple Routing**
   - One EC2 instance running Apache
   - A simple A record pointing to the instance

2. **Failover Routing**
   - Two EC2 instances (primary and secondary) running Apache
   - Health checks for both instances
   - Failover configuration that switches to secondary if primary fails

3. **Geolocation Routing**
   - Three EC2 instances (North America, Europe, and Default) running Apache
   - Geolocation routing based on user's location

## Setup Instructions

1. Clone this repository
2. Update the `domain_name` variable in `variables.tf` with your domain name
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Review the plan:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Testing the Demo

After the infrastructure is created, you can test the different routing policies:

1. **Simple Routing**
   - Access: `http://simple.yourdomain.com`
   - Should show the simple routing server page

2. **Failover Routing**
   - Access: `http://failover.yourdomain.com`
   - Should show the primary server page
   - To test failover, stop the primary server's Apache service:
     ```bash
     ssh ec2-user@primary-server-ip
     sudo systemctl stop httpd
     ```
   - After a few minutes, the traffic should automatically switch to the secondary server

3. **Geolocation Routing**
   - Access: `http://geo.yourdomain.com`
   - Users from North America will see the North America server
   - Users from Europe will see the Europe server
   - Users from other regions will see the default server

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Notes

- The demo uses t3.micro instances to minimize costs
- All instances run Amazon Linux 2023 with Apache
- Security groups allow HTTP (80) and SSH (22) access
- Health checks are configured to check the root path every 30 seconds
- The failover routing will switch to the secondary server if the primary fails three consecutive health checks 