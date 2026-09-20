# IAM Challenge Lab

This challenge builds on the base IAM lab and pushes you to reason about real design tradeoffs instead of just memorizing commands.

## Challenge 1: Lock the Archivist to a Prefix

Your current `archivist` access should already allow writes only to `incoming/`. Prove it using policy simulation and a real CLI test.

Questions:

1. Which API actions should succeed for `incoming/test.txt`?
2. Which should fail for `published/test.txt`?
3. Why is prefix scoping better than bucket-wide write access?

<details>
<summary>Show Solution</summary>

Use the simulator:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account-id>:user/<archivist-user> \
  --action-names s3:PutObject s3:DeleteObject s3:GetObject \
  --resource-arns \
    arn:aws:s3:::<bucket-name>/incoming/test.txt \
    arn:aws:s3:::<bucket-name>/published/test.txt
```

Then verify with live calls:

```bash
aws s3 cp manifest.txt s3://<bucket-name>/incoming/test.txt --profile archivist-lab
aws s3 cp manifest.txt s3://<bucket-name>/published/test.txt --profile archivist-lab
```

Expected result:

- write to `incoming/` succeeds
- write to `published/` fails
- read still succeeds where `GetObject` is allowed

This pattern reduces blast radius if a human or script makes a mistake.
</details>

## Challenge 2: Add MFA Protection to the Support Role

Require MFA before the `support` user can assume the support role.

<details>
<summary>Show Solution</summary>

Update the trust policy to require MFA:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<account-id>:user/<support-user>"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

Apply it:

```bash
aws iam update-assume-role-policy \
  --role-name <support-role-name> \
  --policy-document file://updated-trust-policy.json
```

Architecture takeaway:

- temporary elevation is good
- temporary elevation plus MFA is better for sensitive operations
</details>

## Challenge 3: Model a Workload Role

Create a new role named `publisher-app-role` that can read from `published/` but cannot list the entire bucket.

<details>
<summary>Show Solution</summary>

Example permission policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<bucket-name>/published/*"
    }
  ]
}
```

This is a useful pattern for app workloads that fetch known objects but do not need broad bucket visibility.
</details>

## Challenge 4: Add an Explicit Deny for Deletes

Suppose you want the `archivist` to upload into `incoming/` but never delete objects. Add an explicit deny and observe the result.

<details>
<summary>Show Solution</summary>

Add a statement like this to the archivist policy:

```json
{
  "Sid": "DenyDeletes",
  "Effect": "Deny",
  "Action": "s3:DeleteObject",
  "Resource": "arn:aws:s3:::<bucket-name>/incoming/*"
}
```

Even if another statement allows delete, the explicit deny wins.
</details>

## Challenge 5: Explain the Design

Answer these in your own words:

1. Why use a group for `archivist` and `auditor` instead of attaching policies directly to users?
2. Why is the support role safer than giving the support user direct read access all the time?
3. What problem does the bucket policy solve that the IAM policy does not?
4. When would you choose a role over an IAM user for an application?

## Stretch Goal

Design a cross-account version of this lab:

- Account A owns the S3 bucket
- Account B contains the support engineer
- a cross-account role in Account A grants temporary read-only access

This is one of the most common real-world architect patterns in AWS environments.
