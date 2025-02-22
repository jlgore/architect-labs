# AWS S3 Lifecycle Policy and Versioning Lab

This lab guides you through setting up S3 bucket versioning and lifecycle policies using the AWS CLI. You'll learn how to create a bucket, enable versioning, upload different versions of files, and configure lifecycle rules to manage object transitions and expirations.

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- Basic knowledge of AWS S3 concepts
- A terminal or command prompt

## Lab Steps

### 1. Create an S3 Bucket

First, let's create a new S3 bucket for our lab:

```bash
# Set your bucket name as a variable
BUCKET_NAME="your-unique-bucket-name-$(date +%Y%m%d%H%M%S)"

aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region us-east-1
```

> **Note**: Replace `your-unique-bucket-name` with a globally unique bucket name. For regions other than `us-east-1`, you'll need to specify the `--create-bucket-configuration LocationConstraint=region-name` parameter:

```bash
# For regions other than us-east-1
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region your-region \
    --create-bucket-configuration LocationConstraint=your-region
```

### 2. Enable Versioning on the Bucket

Versioning allows you to preserve, retrieve, and restore every version of objects in your S3 bucket:

```bash
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled
```

### 3. Upload Test Files to Your Bucket

Let's create and upload a few files to test versioning:

#### Create and upload the first version of a file:

```bash
# Create a test file
cat << EOF > test-file.txt
This is version 1 of the test file.
EOF

# Upload the file
aws s3api put-object \
    --bucket $BUCKET_NAME \
    --key test-file.txt \
    --body test-file.txt
```

#### Create and upload the second version of the same file:

```bash
# Update the test file
cat << EOF > test-file.txt
This is version 2 of the test file.
Some content has been updated.
EOF

# Upload the updated file (creates a new version)
aws s3api put-object \
    --bucket $BUCKET_NAME \
    --key test-file.txt \
    --body test-file.txt
```

#### Create and upload a third version:

```bash
# Update the test file again
cat << EOF > test-file.txt
This is version 3 of the test file.
More changes have been made.
This will be the latest version.
EOF

# Upload the updated file (creates a new version)
aws s3api put-object \
    --bucket $BUCKET_NAME \
    --key test-file.txt \
    --body test-file.txt
```

### 4. List All Versions of the Object

Now you can verify that all versions of the file have been stored:

```bash
aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --prefix test-file.txt
```

The output will show all versions with their respective version IDs.

### 5. Create a Lifecycle Policy

Now let's create a lifecycle policy to manage our objects. We'll first create a JSON file defining the policy:

```bash
cat << EOF > lifecycle-policy.json
{
  "Rules": [
    {
      "ID": "Move-to-IA-Then-Glacier",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "documents/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    },
    {
      "ID": "Delete-Old-Versions",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
EOF
```

This policy contains two rules:
1. **Move-to-IA-Then-Glacier**: Transitions objects with the prefix "documents/" to Standard-IA after 30 days, then to Glacier after 90 days, and finally deletes them after 365 days.
2. **Delete-Old-Versions**: Deletes old (noncurrent) versions of objects after 30 days.

### 6. Apply the Lifecycle Policy to the Bucket

Now, apply this lifecycle policy to your bucket:

```bash
aws s3api put-bucket-lifecycle-configuration \
    --bucket $BUCKET_NAME \
    --lifecycle-configuration file://lifecycle-policy.json
```

### 7. Verify the Lifecycle Policy Configuration

Verify that the lifecycle policy has been correctly applied:

```bash
aws s3api get-bucket-lifecycle-configuration \
    --bucket $BUCKET_NAME
```

### 8. Test Object Versioning Operations

Let's explore some common operations with versioned objects:

#### Retrieve a specific version of an object:

```bash
# Replace VERSION_ID with an actual version ID from the list-object-versions command
aws s3api get-object \
    --bucket $BUCKET_NAME \
    --key test-file.txt \
    --version-id VERSION_ID \
    --output-file test-file-v1.txt
```

#### Delete a specific version of an object:

```bash
# Replace VERSION_ID with an actual version ID
aws s3api delete-object \
    --bucket $BUCKET_NAME \
    --key test-file.txt \
    --version-id VERSION_ID
```

#### Create a delete marker (standard delete on a versioned object):

```bash
aws s3api delete-object \
    --bucket $BUCKET_NAME \
    --key test-file.txt
```

This doesn't actually delete the object but creates a delete marker, which is a special type of version.

#### List all delete markers:

```bash
aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --prefix test-file.txt \
    --delete-markers
```

### 9. Upload Files to Test the Lifecycle Policy

Create a test file for the documents/ prefix to test the lifecycle policy:

```bash
# Create a directory for organization
mkdir -p documents

# Create a test document
cat << EOF > documents/report.txt
This is a sample report document.
It will transition through different storage classes 
according to our lifecycle policy.
EOF

# Upload the document to the documents/ prefix
aws s3api put-object \
    --bucket $BUCKET_NAME \
    --key documents/report.txt \
    --body documents/report.txt
```

### 10. Clean Up Resources (Optional)

If you want to clean up after completing the lab:

#### Delete all object versions:

```bash
# First, list all versions
aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --output json > versions.json

# Use a script to extract version IDs and delete all objects
python -c '
import json
with open("versions.json", "r") as f:
    data = json.load(f)
    
for version in data.get("Versions", []):
    print(f"Deleting {version["Key"]} version {version["VersionId"]}...")
    cmd = f"aws s3api delete-object --bucket $BUCKET_NAME --key {version["Key"]} --version-id {version["VersionId"]}"
    import os
    os.system(cmd)

for marker in data.get("DeleteMarkers", []):
    print(f"Deleting marker for {marker["Key"]} version {marker["VersionId"]}...")
    cmd = f"aws s3api delete-object --bucket $BUCKET_NAME --key {marker["Key"]} --version-id {marker["VersionId"]}"
    import os
    os.system(cmd)
'
```

#### Delete the bucket:

```bash
aws s3api delete-bucket \
    --bucket $BUCKET_NAME
```

## Explanation of Key Concepts

### S3 Versioning
Versioning keeps multiple variants of an object in the same bucket. It helps protect against accidental deletions and modifications. When you overwrite an object, S3 creates a new version instead of replacing it.

### Lifecycle Policies
Lifecycle policies automatically manage objects throughout their lifecycle by using rules to define actions. Key components:

- **Transition actions**: Move objects to another storage class (e.g., Standard → Standard-IA → Glacier)
- **Expiration actions**: Remove objects after a specified time
- **NoncurrentVersionExpiration**: Delete previous versions after a set time period

### Storage Classes
- **STANDARD**: Default, high durability, availability, and performance
- **STANDARD_IA**: For infrequently accessed data with rapid access when needed
- **INTELLIGENT_TIERING**: Automatically moves objects between tiers
- **ONEZONE_IA**: Lower cost than STANDARD_IA, stored in a single AZ
- **GLACIER**: Low-cost archival storage with retrieval times from minutes to hours
- **DEEP_ARCHIVE**: Lowest cost storage for long-term retention (retrieval time: hours)

## Practical Use Cases

1. **Data Archiving**: Automatically move older data to cheaper storage
2. **Cost Optimization**: Reduce storage costs by transitioning infrequently accessed data
3. **Retention Compliance**: Ensure data is kept for required periods before deletion
4. **Disaster Recovery**: Maintain multiple object versions for recovery purposes
5. **Storage Management**: Automatically clean up old file versions

## Additional Resources

- [AWS S3 Versioning Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [AWS S3 Lifecycle Configuration Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [AWS S3 Storage Classes Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html)
