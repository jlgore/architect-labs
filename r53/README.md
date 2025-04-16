# Route 53 Routing Demo Environment

This demo environment demonstrates three different Route 53 routing policies with actual web servers, using a subdomain of your existing domain.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured
- Terraform installed
- An existing Route 53 hosted zone for your domain (e.g., example.com)

## Architecture

The demo creates a subdomain (demo.example.com) under your existing domain and sets up:

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
2. Update the variables in `variables.tf`:
   - `parent_domain`: Your existing domain (e.g., "example.com")
   - `subdomain`: The subdomain to create (e.g., "demo.example.com")
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
   - Access: `http://simple.demo.example.com`
   - Should show the simple routing server page

2. **Failover Routing**
   - Access: `http://failover.demo.example.com`
   - Should show the primary server page
   - To test failover, stop the primary server's Apache service:
     ```bash
     ssh ec2-user@primary-server-ip
     sudo systemctl stop httpd
     ```
   - After a few minutes, the traffic should automatically switch to the secondary server

3. **Geolocation Routing**
   - Access: `http://geo.demo.example.com`
   - Users from North America will see the North America server
   - Users from Europe will see the Europe server
   - Users from other regions will see the default server

## DNS Propagation

After applying the configuration:
1. A new hosted zone will be created for your subdomain
2. NS records will be added to your parent domain to delegate the subdomain
3. DNS changes may take up to 48 hours to propagate, though typically it's much faster

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
- The subdomain delegation is handled automatically through NS records in the parent zone 