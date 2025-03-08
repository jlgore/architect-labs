# AWS RDS and EC2 Integration Lab Using Terraform

## Overview
This Terraform project creates an AWS environment that demonstrates the integration between Amazon RDS (Relational Database Service) and EC2 instances. It sets up a complete VPC architecture with public and private subnets, security groups, and a MySQL RDS instance.

## Architecture
- VPC with 4 subnets (2 public, 2 private) across different availability zones
- Internet Gateway for public internet access
- EC2 instance in a public subnet
- RDS MySQL instance in private subnets
- Security groups for both EC2 and RDS
- Network routing for public and private subnets

## Prerequisites
1. Terraform installed (v0.12 or newer)
2. AWS CLI configured with appropriate credentials
3. SSH key pair for EC2 access
4. Basic understanding of AWS services (VPC, EC2, RDS)

## Project Structure 