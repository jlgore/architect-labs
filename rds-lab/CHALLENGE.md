# RDS CLI Challenge Questions

Before starting this challenge, familiarize yourself with the [AWS RDS CLI Reference Documentation](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/rds/index.html). This guide lists all available RDS commands and their options.

## Basic RDS Operations

1. How do you list all RDS instances in your region?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-instances
```

Tip: Add `--query 'DBInstances[].[DBInstanceIdentifier,Engine,DBInstanceStatus]' --output table` for cleaner output
</details>

2. How do you get detailed information about a specific RDS instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-instances \
    --db-instance-identifier my-database
```
</details>

3. How do you list all available RDS engine versions for PostgreSQL?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-engine-versions \
    --engine postgres
```
</details>

4. How do you create a DB subnet group?

<details>
<summary>Show Solution</summary>

```bash
aws rds create-db-subnet-group \
    --db-subnet-group-name mysubnetgroup \
    --db-subnet-group-description "My DB subnet group" \
    --subnet-ids subnet-1234567890abcdef0 subnet-0987654321fedcba0
```
</details>

5. How do you list all DB snapshots?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-snapshots
```
</details>

6. How do you create a snapshot of a DB instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds create-db-snapshot \
    --db-instance-identifier my-database \
    --db-snapshot-identifier my-database-snapshot
```
</details>

7. How do you list all parameter groups?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-parameter-groups
```
</details>

8. How do you view the parameters in a specific parameter group?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-parameters \
    --db-parameter-group-name myparametergroup
```
</details>

9. How do you list all option groups?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-option-groups
```
</details>

10. How do you stop a DB instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds stop-db-instance \
    --db-instance-identifier my-database
```
</details>

11. How do you start a stopped DB instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds start-db-instance \
    --db-instance-identifier my-database
```
</details>

12. How do you modify the storage size of a DB instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds modify-db-instance \
    --db-instance-identifier my-database \
    --allocated-storage 50
```
</details>

13. How do you list all DB security groups?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-security-groups
```
</details>

14. How do you get the endpoint address of a specific DB instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds describe-db-instances \
    --db-instance-identifier my-database \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```
</details>

15. How do you reboot a DB instance?

<details>
<summary>Show Solution</summary>

```bash
aws rds reboot-db-instance \
    --db-instance-identifier my-database
```
</details>

## Tips for Success

1. Use `aws rds help` to explore available commands
2. Common command prefixes:
   - `describe-` (to list/view resources)
   - `create-` (to create new resources)
   - `modify-` (to change existing resources)
   - `delete-` (to remove resources)
3. Use `--query` to filter output
4. Use `--output table` for readable output

## Important Notes

- Always replace example identifiers (like 'my-database') with your actual resource identifiers
- Some commands may take several minutes to complete
- Be careful with delete operations as they may be irreversible
- Some modifications may cause database downtime

## Submission Format

For each challenge:
1. Write the complete AWS CLI command
2. Test it in your environment (with appropriate identifiers)
3. Note what the command does and when you might use it
4. Document any errors you encountered and how you resolved them

Remember to replace example identifiers with actual values from your environment.