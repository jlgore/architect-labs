# S3 CLI Challenge Questions

Before starting this challenge, familiarize yourself with the [AWS S3 CLI Reference Documentation](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/index.html). Note that there are two sets of S3 commands:
- `aws s3` for high-level S3 operations
- `aws s3api` for low-level API operations

## Basic S3 Operations

1. How do you list all your S3 buckets?

<details>
<summary>Show Solution</summary>

```bash
aws s3 ls
```
</details>

2. How do you list all objects in a specific bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3 ls s3://my-bucket
```
</details>

3. How do you create a new S3 bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3 mb s3://my-new-bucket
```
</details>

4. How do you upload a file to S3?

<details>
<summary>Show Solution</summary>

```bash
aws s3 cp myfile.txt s3://my-bucket/
```
</details>

5. How do you download a file from S3?

<details>
<summary>Show Solution</summary>

```bash
aws s3 cp s3://my-bucket/myfile.txt ./
```
</details>

6. How do you delete a file from S3?

<details>
<summary>Show Solution</summary>

```bash
aws s3 rm s3://my-bucket/myfile.txt
```
</details>

7. How do you sync a local directory with an S3 bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3 sync ./my-local-dir s3://my-bucket/
```
</details>

8. How do you make an object public using ACL? (Note: bucket must allow ACLs)

<details>
<summary>Show Solution</summary>

```bash
aws s3api put-object-acl \
    --bucket my-bucket \
    --key myfile.txt \
    --acl public-read
```
</details>

9. How do you check if a specific file exists in a bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3api head-object \
    --bucket my-bucket \
    --key myfile.txt
```
</details>

10. How do you create a new folder in a bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3api put-object \
    --bucket my-bucket \
    --key myfolder/
```
</details>

11. How do you copy an object from one bucket to another?

<details>
<summary>Show Solution</summary>

```bash
aws s3 cp s3://source-bucket/myfile.txt s3://destination-bucket/
```
</details>

12. How do you list all objects in a bucket with a specific prefix?

<details>
<summary>Show Solution</summary>

```bash
aws s3 ls s3://my-bucket/folder/
```
</details>

13. How do you get the size of a bucket (total storage used)?

<details>
<summary>Show Solution</summary>

```bash
aws s3api list-objects-v2 \
    --bucket my-bucket \
    --query "sum(Contents[].Size)"
```
</details>

14. How do you enable versioning on a bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3api put-bucket-versioning \
    --bucket my-bucket \
    --versioning-configuration Status=Enabled
```
</details>

15. How do you delete an empty bucket?

<details>
<summary>Show Solution</summary>

```bash
aws s3 rb s3://my-bucket
```
</details>

## Tips for Success

1. Understanding the difference between `aws s3` and `aws s3api`:
   - `aws s3`: Higher-level commands for common operations
   - `aws s3api`: Lower-level commands for specific API operations

2. Common `aws s3` commands:
   - `ls`: List buckets or objects
   - `mb`: Make bucket
   - `rb`: Remove bucket
   - `cp`: Copy objects
   - `mv`: Move objects
   - `rm`: Remove objects
   - `sync`: Sync directories/buckets

3. Common `aws s3api` commands:
   - `create-bucket`
   - `delete-bucket`
   - `put-object`
   - `get-object`
   - `list-objects-v2`
   - `put-bucket-policy`
   - `put-bucket-versioning`

4. Use `--dryrun` with `aws s3` commands to preview operations

## Important Notes

- Always replace 'my-bucket' with your actual bucket name
- Bucket names must be globally unique across all AWS accounts
- Some regions require specific syntax for bucket creation
- Be careful with delete operations
- Remember that sync operations can overwrite files

## Submission Format

For each challenge:
1. Write the complete AWS CLI command
2. Test it in your environment
3. Note what the command does and when you might use it
4. Document any errors you encountered and how you resolved them

Remember to replace example bucket names and paths with actual values from your environment. 