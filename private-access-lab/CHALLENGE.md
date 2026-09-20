# Private Access Challenge Lab

This challenge extends the base private access lab and focuses on the design decisions behind keeping workloads off the public internet.

## Challenge 1: Explain Why NAT Might Be Wasteful Here

Your workload only needs S3 and DynamoDB. Should you add a NAT gateway?

<details>
<summary>Show Solution</summary>

Not by default.

If the workload only needs S3 and DynamoDB, gateway endpoints are usually cheaper and tighter than a NAT gateway.

Why:

- lower cost for this use case
- private service path
- less broad outbound access
- clearer intent in the architecture
</details>

## Challenge 2: Add an Endpoint Policy

Restrict the S3 endpoint so it can only access one bucket, not any S3 bucket in the account.

<details>
<summary>Show Solution</summary>

Attach an endpoint policy that narrows S3 actions and resources to the specific bucket ARN and object ARN paths.

This is useful because:

- route-level private access alone is not enough
- endpoint policies can narrow what traffic is allowed through that path
</details>

## Challenge 3: Bastion vs Session Manager

Explain when a bastion host is still justified and when Session Manager is the better default.

<details>
<summary>Show Solution</summary>

Prefer Session Manager when:

- administrators only need shell access and command execution
- you want auditability and less exposed infrastructure
- you want to avoid SSH key management

Use a bastion only when there is a real tool or protocol requirement that Session Manager does not meet cleanly.
</details>

## Challenge 4: Protect the Bucket Further

Add a deny statement so the bucket rejects requests that do not come through the intended VPC endpoint.

<details>
<summary>Show Solution</summary>

A strong version of the policy uses an explicit deny when `aws:sourceVpce` does not match the expected endpoint.

This is stronger because:

- explicit deny wins
- accidental broader allows elsewhere are less risky
</details>

## Challenge 5: Multi-AZ Improvement

How would you make this design more highly available without making it public?

<details>
<summary>Show Solution</summary>

Add:

- another private subnet in a second AZ
- workload placement across both AZs
- endpoint coverage that supports those subnets and route tables

Private does not mean single-AZ. Availability and privacy should both be designed intentionally.
</details>

## Challenge 6: Explain Interface vs Gateway Endpoints

Why are S3 and DynamoDB often taught differently from Systems Manager or Secrets Manager?

<details>
<summary>Show Solution</summary>

Because S3 and DynamoDB support gateway endpoints, which are usually cheaper and route-table based.

Many other services use interface endpoints, which:

- live in subnets
- use security groups
- cost more
- are still valuable when you need private access to those services
</details>

## Stretch Goal

Design a fully private application stack with:

- ALB in private subnets
- app instances in private subnets
- RDS in private subnets
- VPC endpoints for S3, DynamoDB, Secrets Manager, and Systems Manager

Then explain which services, if any, still need controlled public entry points.
