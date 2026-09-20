# IAM Architecture Lab

This lab teaches core AWS identity and access design through a small, low-cost scenario: a fictional media team needs controlled access to a shared S3 archive, an application role, and a break-glass support role.

The lab is intentionally lightweight:

- IAM resources are free
- S3 usage stays tiny
- No EC2, RDS, or NAT costs

## Learning Objectives

By the end of this lab, you should be able to:

- Explain when to use users, groups, roles, and resource policies
- Create least-privilege policies for human and workload access
- Attach permissions to groups instead of individual users where appropriate
- Create a role with a trust policy and assume it with STS
- Use a bucket policy to complement identity-based permissions
- Validate access decisions with AWS CLI commands and policy simulation

## Scenario

You are designing access for the `Pixel Pets Archive`, a team that stores image assets in S3.

There are three personas:

- `archivist` can upload and read objects in a team bucket
- `auditor` can only list and read objects
- `support` has no standing write access, but can assume a temporary troubleshooting role when needed

You will implement the architecture using:

- IAM users
- IAM groups
- IAM managed policies you create
- One assumable IAM role
- One S3 bucket policy

## Architecture Decisions

This lab focuses on a few important Solutions Architect patterns:

- Human permissions flow through groups
- Temporary elevated access flows through STS assume-role
- Workload-style access is modeled with a role, not embedded credentials
- S3 authorization can involve both identity-based and resource-based policies

## Prerequisites

- AWS CLI configured with credentials that can manage IAM and S3
- `jq` installed
- Permission to create IAM users, groups, roles, policies, and an S3 bucket

## Cost

Expected cost is near zero if you clean up:

- IAM resources: no direct cost
- S3: a small bucket with a few tiny text files

## Lab Overview

1. Create a tiny S3 archive bucket
2. Create users and groups for the team
3. Create least-privilege customer-managed IAM policies
4. Verify permissions for the `archivist` and `auditor`
5. Create a `support-readonly-role` with a trust policy
6. Assume the role with STS and verify temporary access
7. Add a bucket policy that only allows secure transport
8. Clean up all resources

## Step 1: Set Variables

```bash
LAB_ID=$(date +%Y%m%d%H%M%S)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

BUCKET_NAME="pixel-pets-archive-${ACCOUNT_ID}-${LAB_ID}"

ARCHIVIST_USER="archivist-${LAB_ID}"
AUDITOR_USER="auditor-${LAB_ID}"
SUPPORT_USER="support-${LAB_ID}"

ARCHIVISTS_GROUP="pixel-pets-archivists-${LAB_ID}"
AUDITORS_GROUP="pixel-pets-auditors-${LAB_ID}"

ARCHIVIST_POLICY="pixel-pets-archivist-policy-${LAB_ID}"
AUDITOR_POLICY="pixel-pets-auditor-policy-${LAB_ID}"
SUPPORT_ASSUME_POLICY="pixel-pets-support-assume-policy-${LAB_ID}"
SUPPORT_ROLE="pixel-pets-support-readonly-role-${LAB_ID}"

echo "Using bucket: $BUCKET_NAME"
echo "Using region: $AWS_REGION"
```

## Step 2: Create the S3 Bucket and Seed Data

Create a small bucket and upload two tiny objects so your access tests have real targets.

```bash
if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled
```

Create two local files and upload them:

```bash
printf 'Pixel Pets asset manifest\n' > manifest.txt
printf 'cat, corgi, gecko\n' > pets.txt

aws s3 cp manifest.txt "s3://${BUCKET_NAME}/incoming/manifest.txt"
aws s3 cp pets.txt "s3://${BUCKET_NAME}/published/pets.txt"
```

## Step 3: Create Users and Groups

Use groups for durable team permissions. This scales better than attaching policies directly to users.

```bash
aws iam create-user --user-name "$ARCHIVIST_USER"
aws iam create-user --user-name "$AUDITOR_USER"
aws iam create-user --user-name "$SUPPORT_USER"

aws iam create-group --group-name "$ARCHIVISTS_GROUP"
aws iam create-group --group-name "$AUDITORS_GROUP"

aws iam add-user-to-group --user-name "$ARCHIVIST_USER" --group-name "$ARCHIVISTS_GROUP"
aws iam add-user-to-group --user-name "$AUDITOR_USER" --group-name "$AUDITORS_GROUP"
```

## Step 4: Create Customer-Managed Policies

Create the policy files locally first. This makes the permissions easier to review and version.

### Archivist policy

`archivist` should be able to:

- list the bucket
- read any object
- upload into `incoming/`
- delete only objects in `incoming/`

```bash
cat > archivist-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Sid": "ReadAllObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    },
    {
      "Sid": "WriteIncomingObjects",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/incoming/*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name "$ARCHIVIST_POLICY" \
  --policy-document file://archivist-policy.json
```

### Auditor policy

`auditor` should only be able to list and read objects.

```bash
cat > auditor-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Sid": "ReadAllObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name "$AUDITOR_POLICY" \
  --policy-document file://auditor-policy.json
```

Capture the policy ARNs:

```bash
ARCHIVIST_POLICY_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='${ARCHIVIST_POLICY}'].Arn" \
  --output text)

AUDITOR_POLICY_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='${AUDITOR_POLICY}'].Arn" \
  --output text)
```

Attach them to groups:

```bash
aws iam attach-group-policy \
  --group-name "$ARCHIVISTS_GROUP" \
  --policy-arn "$ARCHIVIST_POLICY_ARN"

aws iam attach-group-policy \
  --group-name "$AUDITORS_GROUP" \
  --policy-arn "$AUDITOR_POLICY_ARN"
```

## Step 5: Create Access Keys for Lab Testing

In production, prefer federation or IAM Identity Center for humans. In this lab, access keys make it easy to test permission boundaries with the CLI.

```bash
aws iam create-access-key --user-name "$ARCHIVIST_USER"
aws iam create-access-key --user-name "$AUDITOR_USER"
aws iam create-access-key --user-name "$SUPPORT_USER"
```

Save the outputs securely when they are returned. You will use them in temporary CLI profiles.

Configure three profiles:

```bash
aws configure --profile archivist-lab
aws configure --profile auditor-lab
aws configure --profile support-lab
```

Use the access key and secret from each `create-access-key` response. Set the default region to `$AWS_REGION`.

## Step 6: Verify Group-Based Permissions

Test each persona with real CLI calls.

### Archivist tests

Should succeed:

```bash
aws s3 ls "s3://${BUCKET_NAME}" --profile archivist-lab
aws s3 cp manifest.txt "s3://${BUCKET_NAME}/incoming/archivist-test.txt" --profile archivist-lab
aws s3 cp "s3://${BUCKET_NAME}/published/pets.txt" - --profile archivist-lab
```

Should fail because writes outside `incoming/` are not allowed:

```bash
aws s3 cp manifest.txt "s3://${BUCKET_NAME}/published/should-fail.txt" --profile archivist-lab
```

### Auditor tests

Should succeed:

```bash
aws s3 ls "s3://${BUCKET_NAME}" --profile auditor-lab
aws s3 cp "s3://${BUCKET_NAME}/published/pets.txt" - --profile auditor-lab
```

Should fail because auditors are read-only:

```bash
aws s3 cp manifest.txt "s3://${BUCKET_NAME}/incoming/auditor-test.txt" --profile auditor-lab
```

## Step 7: Create a Temporary Support Role

Now model temporary elevated access. The `support` user should not have direct S3 read permissions, but should be allowed to assume a read-only role.

### Create the role trust policy

```bash
cat > support-role-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:user/${SUPPORT_USER}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "$SUPPORT_ROLE" \
  --assume-role-policy-document file://support-role-trust.json
```

### Attach read-only S3 permissions to the role

```bash
aws iam attach-role-policy \
  --role-name "$SUPPORT_ROLE" \
  --policy-arn "$AUDITOR_POLICY_ARN"
```

### Allow the support user to assume the role

```bash
cat > support-assume-role-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/${SUPPORT_ROLE}"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name "$SUPPORT_ASSUME_POLICY" \
  --policy-document file://support-assume-role-policy.json

SUPPORT_ASSUME_POLICY_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='${SUPPORT_ASSUME_POLICY}'].Arn" \
  --output text)

aws iam attach-user-policy \
  --user-name "$SUPPORT_USER" \
  --policy-arn "$SUPPORT_ASSUME_POLICY_ARN"
```

## Step 8: Assume the Role with STS

The `support` user should not be able to read the bucket directly.

This should fail:

```bash
aws s3 ls "s3://${BUCKET_NAME}" --profile support-lab
```

Assume the role:

```bash
ROLE_SESSION=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${SUPPORT_ROLE}" \
  --role-session-name support-investigation \
  --profile support-lab)

export AWS_ACCESS_KEY_ID=$(echo "$ROLE_SESSION" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$ROLE_SESSION" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$ROLE_SESSION" | jq -r '.Credentials.SessionToken')
export AWS_REGION="$AWS_REGION"
```

Now the temporary session should succeed:

```bash
aws s3 ls "s3://${BUCKET_NAME}"
aws s3 cp "s3://${BUCKET_NAME}/published/pets.txt" -
```

But writing should still fail, because the role only has read permissions:

```bash
aws s3 cp manifest.txt "s3://${BUCKET_NAME}/incoming/support-should-fail.txt"
```

When finished, clear the temporary credentials:

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_REGION
```

## Step 9: Add a Bucket Policy for Secure Transport

Now add a resource-based control. This policy denies any S3 request that is not using TLS.

```bash
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://bucket-policy.json
```

Why this matters:

- identity policy says who can do something
- resource policy adds guardrails around how access happens
- explicit deny wins over allow

## Step 10: Optional Policy Simulation

Use the IAM simulator to reason about access before or after testing.

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:user/${AUDITOR_USER}" \
  --action-names s3:GetObject s3:PutObject \
  --resource-arns "arn:aws:s3:::${BUCKET_NAME}/published/pets.txt"
```

Try the same command for the `archivist` user and compare the results.

## What You Should Observe

- Group-attached policies scale better than user-attached policies
- The `auditor` can read but not write
- The `archivist` can write only to the `incoming/` prefix
- The `support` user has no direct access until assuming a role
- The assumed role gives temporary scoped access
- Bucket policies and IAM policies combine, and explicit deny still wins

## Design Discussion

These are the key architecture takeaways:

1. Use groups for team membership and baseline human permissions.
2. Use roles for temporary elevation and workload identities.
3. Prefer short-lived credentials over long-lived powerful credentials.
4. Scope S3 access down to prefixes when a full bucket grant is unnecessary.
5. Add resource-policy guardrails for requirements like TLS-only access.

## Cleanup

Delete objects first:

```bash
aws s3 rm "s3://${BUCKET_NAME}" --recursive
aws s3api delete-bucket-policy --bucket "$BUCKET_NAME"
aws s3api delete-bucket --bucket "$BUCKET_NAME"
```

Delete access keys for each user. First list them:

```bash
aws iam list-access-keys --user-name "$ARCHIVIST_USER"
aws iam list-access-keys --user-name "$AUDITOR_USER"
aws iam list-access-keys --user-name "$SUPPORT_USER"
```

Delete each returned access key:

```bash
aws iam delete-access-key --user-name "$ARCHIVIST_USER" --access-key-id <archivist-key-id>
aws iam delete-access-key --user-name "$AUDITOR_USER" --access-key-id <auditor-key-id>
aws iam delete-access-key --user-name "$SUPPORT_USER" --access-key-id <support-key-id>
```

Detach and delete policies, groups, role, and users:

```bash
aws iam detach-group-policy --group-name "$ARCHIVISTS_GROUP" --policy-arn "$ARCHIVIST_POLICY_ARN"
aws iam detach-group-policy --group-name "$AUDITORS_GROUP" --policy-arn "$AUDITOR_POLICY_ARN"

aws iam detach-user-policy --user-name "$SUPPORT_USER" --policy-arn "$SUPPORT_ASSUME_POLICY_ARN"
aws iam detach-role-policy --role-name "$SUPPORT_ROLE" --policy-arn "$AUDITOR_POLICY_ARN"

aws iam remove-user-from-group --user-name "$ARCHIVIST_USER" --group-name "$ARCHIVISTS_GROUP"
aws iam remove-user-from-group --user-name "$AUDITOR_USER" --group-name "$AUDITORS_GROUP"

aws iam delete-group --group-name "$ARCHIVISTS_GROUP"
aws iam delete-group --group-name "$AUDITORS_GROUP"

aws iam delete-role --role-name "$SUPPORT_ROLE"

aws iam delete-user --user-name "$ARCHIVIST_USER"
aws iam delete-user --user-name "$AUDITOR_USER"
aws iam delete-user --user-name "$SUPPORT_USER"

aws iam delete-policy --policy-arn "$ARCHIVIST_POLICY_ARN"
aws iam delete-policy --policy-arn "$AUDITOR_POLICY_ARN"
aws iam delete-policy --policy-arn "$SUPPORT_ASSUME_POLICY_ARN"
```

Remove the local files:

```bash
rm -f manifest.txt pets.txt archivist-policy.json auditor-policy.json support-role-trust.json support-assume-role-policy.json bucket-policy.json
```

## Next Steps

After this lab, a good follow-on is to extend the design with one of these patterns:

1. Add an EC2 or Lambda workload role that can read only `published/`
2. Add a permissions boundary for junior admins
3. Replace IAM users with IAM Identity Center for human access
4. Add an S3 bucket policy that restricts access to a specific VPC endpoint
