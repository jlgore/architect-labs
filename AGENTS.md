# Repository Guidelines

## Project Structure & Module Organization
- `cfn/`: CloudFormation templates and app code. App lives in `cfn/app/` (Express + MySQL); Lambda functions in `cfn/lambda/*`.
- `*/terraform/`: Most labs (e.g., `vpc/`, `dynamodb-lab/`, `rds-lab/`, `minecraft-ecs/`) include Terraform in a `terraform/` subfolder. Check each lab’s README first.
- `ami/`: Packer template and helper script for building a student AMI.
- Other lab folders (e.g., `ec2-efs/`, `ha-wordpress/`, `s3-*`, `db_caching/`, `duckdb/`) follow the same README‑driven pattern.

## Build, Test, and Development Commands
- CloudFormation: `aws cloudformation validate-template --template-body file://cfn/web-app-stack.yaml` (lint/validate). Deploy with `aws cloudformation deploy --template-file cfn/web-app-stack.yaml --stack-name my-web-app --parameter-overrides ...`.
- App (local): `cd cfn/app && npm install && sudo npm start` (listens on port 80). Test API: `sudo ./test-api.sh localhost`.
- Lambda (zip): `cd cfn/lambda/hono-api && npm install && zip -r function.zip .` (upload via CFN params or console).
- Terraform: `cd <lab>/terraform && terraform fmt -recursive && terraform init && terraform validate && terraform plan` then `terraform apply`.
- Packer: `cd ami && ./build.sh` (captures AMI ID to `ami/amiId.txt`).

## Coding Style & Naming Conventions
- Indentation: 2 spaces for YAML, HCL, and JS.
- Filenames: kebab-case for templates (e.g., `web-app-stack.yaml`), `snake_case` for Terraform variable names.
- JS: CommonJS modules; semicolons; prefer descriptive names; environment variables in UPPER_SNAKE_CASE.
- Formatting: run `terraform fmt -recursive`; use `cfn-lint` and `yamllint` if available.

## Testing Guidelines
- CloudFormation: `aws cloudformation validate-template` and (optionally) `cfn-lint cfn/*.yaml`.
- Terraform: `terraform validate` (optionally `tflint`). Prefer idempotent changes and least-privilege IAM.
- App/API: after deploy, run `cfn/app/test-api.sh <host>`; include sample outputs in PRs.

## Commit & Pull Request Guidelines
- Commits: imperative and scoped (e.g., `cfn: add ALB health checks`, `terraform(dynamodb-lab): add GSI`). Small, focused commits.
- PRs: describe what/why, list affected paths, include validation evidence (e.g., `validate-template`, `terraform plan` diff), and screenshots/CLI outputs when relevant. Update lab READMEs when behavior changes.

## Security & Configuration Tips
- Do not commit secrets/keys. Use parameterized CFN, TF vars files (provide `*.example`), and environment variables.
- Tag resources consistently (e.g., `Name`, `Project`, `Environment`).
- Be cost-aware; document cleanup: `aws cloudformation delete-stack ...`, `terraform destroy`.

## Agent-Specific Notes
- Keep changes scoped to the lab directory you touch; follow nested READMEs.
- Prefer minimal diffs, consistent indentation, and formatter/linter checks.
- Avoid renames/moves across labs without clear rationale and updated docs.

