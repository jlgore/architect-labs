# DynamoDB Lab with Terraform

This directory contains Terraform configuration to set up the DynamoDB lab environment.

## Files

- `main.tf` - Main Terraform configuration file that creates the DynamoDB table and GSI
- `variables.tf` - Variable definitions for the Terraform configuration
- `outputs.tf` - Output values that will be displayed after Terraform apply
- `data.tf` - Contains sample data definitions
- `data_loader.tf` - Contains logic to load sample data into DynamoDB

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (version 0.12+)

## Usage

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Review the planned changes:
   ```
   terraform plan
   ```

3. Apply the configuration:
   ```
   terraform apply
   ```

4. When you're done with the lab, destroy the resources:
   ```
   terraform destroy
   ```

## Notes

- The configuration creates a DynamoDB table with PAY_PER_REQUEST billing mode
- Sample data is loaded using a local-exec provisioner
- The table has a Global Secondary Index on the Email attribute

## Lab Exercises

After applying the Terraform configuration, you can follow the exercises in the main README.md file to interact with the DynamoDB table using AWS CLI. 