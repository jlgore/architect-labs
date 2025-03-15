# EC2 CLI Challenge Questions

Before starting this challenge, familiarize yourself with the [AWS EC2 CLI Reference Documentation](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/index.html). This comprehensive guide lists all available EC2 commands and their options.

## Basic EC2 Operations

1. How do you list all EC2 instances in your region?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-instances
```

The command shows all instances and their details. To make it more readable, you can add:
- `--query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]'`
- `--output table`
</details>

2. How do you find the public IP address of a specific instance?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-instances \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[].Instances[].PublicIpAddress' \
    --output text
```
</details>

3. How do you find all available Amazon Linux 2 AMIs?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available"
```
</details>

4. How do you start a stopped EC2 instance?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 start-instances --instance-ids i-1234567890abcdef0
```
</details>

5. How do you stop a running EC2 instance?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
```
</details>

6. How do you add a tag to an existing EC2 instance?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 create-tags \
    --resources i-1234567890abcdef0 \
    --tags Key=Environment,Value=Production
```
</details>

7. How do you list all security groups?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-security-groups
```
</details>

8. How do you create a new security group?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 create-security-group \
    --group-name MySecurityGroup \
    --description "My security group description"
```
</details>

9. How do you list all available key pairs?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-key-pairs
```
</details>

10. How do you get the console output of an instance?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 get-console-output --instance-ids i-1234567890abcdef0
```
</details>

11. How do you list all EBS volumes?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-volumes
```
</details>

12. How do you create a new EBS volume?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 create-volume \
    --availability-zone us-east-1a \
    --size 8 \
    --volume-type gp2
```
</details>

13. How do you list all snapshots owned by your account?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 describe-snapshots --owner-ids self
```
</details>

14. How do you create a snapshot of an EBS volume?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 create-snapshot \
    --volume-id vol-1234567890abcdef0 \
    --description "My snapshot"
```
</details>

15. How do you terminate an EC2 instance?

<details>
<summary>Show Solution</summary>

```bash
aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
```
</details>

## Tips for Success

1. Use `aws ec2 help` to explore available commands
2. Most commands start with either:
   - `describe-` (to list/view resources)
   - `create-` (to create new resources)
   - `delete-` (to remove resources)
3. Use `--query` to filter output
4. Use `--output table` for readable output

## Submission Format

For each challenge:
1. Write the complete AWS CLI command
2. Test it in your environment (with appropriate IDs)
3. Note what the command does and when you might use it

Remember to replace example IDs (like i-1234567890abcdef0) with actual IDs from your environment.