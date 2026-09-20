# Architect Labs

Hands-on AWS labs for learning core Solutions Architect skills with AWS CLI, Terraform, CloudFormation, Packer, and small sample apps.

## Table of Contents
- [What This Repo Covers](#what-this-repo-covers)
- [How To Use This Repo](#how-to-use-this-repo)
- [Lab Catalog](#lab-catalog)
- [Suggested Learning Path](#suggested-learning-path)
- [Infrastructure Tooling](#infrastructure-tooling)
- [Validation and Cleanup](#validation-and-cleanup)
- [Solutions Architect Coverage Review](#solutions-architect-coverage-review)

## What This Repo Covers

This repository is organized as a set of mostly independent labs. The collection currently covers:

- Networking foundations: VPCs, subnets, route tables, internet gateways, NAT, peering, Route 53
- Compute and scaling: EC2, Auto Scaling, Application Load Balancers, AMIs
- Storage: S3 website hosting, S3 lifecycle/versioning, EFS
- Databases: RDS, DynamoDB, caching, basic data pipelines
- Containers and serverless: ECS, Lambda microservices, CloudFormation serverless examples
- Reliability patterns: high availability, failover, shared storage, backup-oriented challenges

Most directories include their own README with step-by-step instructions. Several labs also include `CHALLENGE.md` files with extension exercises and guided solutions.

## How To Use This Repo

1. Start with a single lab directory.
2. Read that directory's `README.md` before running commands.
3. Prefer the lab-local deployment instructions over assumptions from other folders.
4. Clean up resources as soon as you finish to avoid ongoing cost.
5. Use the challenge files after the base lab if you want deeper practice.

Recommended prerequisites:

- AWS account with permission to create the resources used in the target lab
- AWS CLI configured
- Terraform installed for `terraform/` labs
- Basic familiarity with VPC, IAM, EC2, S3, and RDS concepts

## Lab Catalog

| Path | Focus Area | Primary Services | Tooling | Notes |
| --- | --- | --- | --- | --- |
| `vpc/` | Core networking | VPC, subnets, IGW, route tables, security groups | AWS CLI, Terraform | Includes base lab, Terraform version, peering example, and challenge |
| `iam-lab/` | Identity and access design | IAM, STS, S3 | AWS CLI | Covers users, groups, roles, trust policies, and least privilege |
| `cloudfront-lab/` | Edge delivery and CDN design | CloudFront, S3, ACM, Route 53 | AWS CLI | Covers private origins, OAC, HTTPS, caching, and invalidation |
| `event-driven-lab/` | Async integration patterns | SNS, SQS, DLQ, EventBridge concepts | AWS CLI | Covers fanout, buffering, retries, and failure isolation |
| `private-access-lab/` | Private connectivity patterns | VPC endpoints, S3, DynamoDB, SSM, EC2 | AWS CLI | Covers private subnets, gateway endpoints, and Session Manager access |
| `observability-lab/` | Monitoring and operations | CloudWatch, SNS, CloudTrail | AWS CLI | Covers logs, metrics, alarms, dashboards, and audit visibility |
| `r53/` | DNS and routing | Route 53, health checks, EC2 | Terraform | Covers simple, failover, and geolocation routing |
| `cfn/` | Infrastructure as code | CloudFormation, EC2, ALB, RDS, Lambda | CloudFormation, Node.js | Includes CloudMart app and serverless examples |
| `high-availability/` | HA web patterns | ALB, Auto Scaling, EC2, VPC, NAT | AWS CLI, Terraform | Good core reliability lab |
| `ha-wordpress/` | HA multi-tier app | ALB, Auto Scaling, RDS, EC2, EFS | AWS CLI | Includes challenge around failover and shared storage |
| `ec2-efs/` | Shared file storage | EC2, EFS, VPC | AWS CLI, Terraform | Useful for persistence and multi-AZ storage concepts |
| `rds-lab/` | Relational databases | RDS PostgreSQL, VPC, security groups | AWS CLI, Terraform, SQL | Includes SQL data and challenge questions |
| `dynamodb-lab/` | NoSQL fundamentals | DynamoDB | AWS CLI, Terraform | Includes table design, queries, scans, and GSI basics |
| `db_caching/` | Caching layer patterns | Redis, Postgres, app cache flow | SST, Next.js | App-focused example of cache-aside architecture |
| `lambda-microservices/` | Serverless application design | Lambda, Function URLs, RDS | Terraform, Python | Useful for decomposition and service-to-service communication |
| `minecraft-ecs/` | Containers on AWS | ECS, Fargate, VPC, CloudWatch, optional data pipeline | Terraform, AWS CLI | Includes challenge and extended setup docs |
| `s3-website-hosting/` | Static hosting | S3 website hosting | AWS CLI | Simple entry lab for object storage and public content |
| `s3-lifecycle-versioning/` | Data durability and lifecycle | S3 versioning, lifecycle rules | AWS CLI | Good storage governance lab |
| `ami/` | Golden image workflow | EC2, AMI, Packer | Packer, shell | Builds a reusable student AMI |
| `duckdb/` | Security and analysis | EC2, S3, RDS, DuckDB | AWS CLI, SQL | More security/CSPM oriented than architect-core |

## Suggested Learning Path

If you want a progression aligned to associate-level architecture concepts, this order works well:

1. `vpc/`
2. `iam-lab/`
3. `s3-website-hosting/`
4. `cloudfront-lab/`
5. `s3-lifecycle-versioning/`
6. `event-driven-lab/`
7. `private-access-lab/`
8. `observability-lab/`
9. `rds-lab/`
10. `dynamodb-lab/`
11. `ec2-efs/`
12. `high-availability/`
13. `r53/`
14. `cfn/`
15. `lambda-microservices/`
16. `ha-wordpress/`
17. `minecraft-ecs/`
18. `db_caching/`
19. `ami/`

Use `CHALLENGE.md` files after the matching lab to reinforce the design tradeoffs.

## Infrastructure Tooling

- CloudFormation content lives in `cfn/`
- Terraform content lives under each lab's `terraform/` directory when present
- App code is mainly under `cfn/app/`, `cfn/lambda/`, `lambda-microservices/terraform/lambda_functions/`, and `db_caching/db_cache/`
- Packer content lives in `ami/`

## Validation and Cleanup

Common validation commands:

```bash
aws cloudformation validate-template --template-body file://cfn/web-app-stack.yaml
terraform fmt -recursive
terraform validate
terraform plan
```

Common cleanup patterns:

```bash
aws cloudformation delete-stack --stack-name <stack-name>
terraform destroy
```

Check the lab-local README before deleting resources because some labs create multiple dependent services.

## Solutions Architect Coverage Review

The repo already covers a strong portion of AWS Solutions Architect Associate ground:

- Networking: VPC, routing, DNS, peering
- Identity: IAM users, groups, roles, STS assume-role, trust policies
- Storage: S3, EFS
- Compute: EC2, AMIs, ECS, Lambda
- Databases: RDS, DynamoDB, caching
- Reliability: ALB, Auto Scaling, failover, multi-AZ design patterns
- Operations: CloudWatch logs, metrics, alarms, dashboards, CloudTrail basics
- IaC: CloudFormation, Terraform, Packer

The biggest gaps I found are below.

### Secondary gaps

1. Disaster recovery patterns beyond single-lab failover
2. Multi-account governance and Organizations
3. KMS and encryption architecture
4. API Gateway patterns
5. Cost optimization exercises
6. Storage tier selection tradeoff lab comparing EBS, EFS, S3, instance store

### Current content quality notes

- The root README previously looked mostly like a single CloudFormation app guide rather than a repo index; that is now fixed.
- `db_caching/` lacked a directory-level README, which made the folder easy to miss.
- Several labs are detailed but very long. Over time, it would help to standardize each lab README around: objectives, architecture, prerequisites, steps, validation, cleanup, challenge.

If you want to extend the repo specifically for Solutions Architect learners, the best next additions would be:

1. `kms-encryption-lab/`
2. `organizations-governance-lab/`
3. `cost-optimization-lab/`
4. `api-gateway-lab/`
5. `disaster-recovery-lab/`
