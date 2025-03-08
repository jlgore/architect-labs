# AWS DynamoDB Lab with AWS CLI

This lab will guide you through using AWS DynamoDB with the AWS CLI in CloudShell. You'll learn how to create tables, insert data, query data, and perform basic operations.

## Prerequisites

- AWS account with access to CloudShell
- Basic understanding of command line interfaces

## Lab Overview

1. Launch AWS CloudShell
2. Create a DynamoDB table
3. Insert data into the table
4. Query and scan the table
5. Update and delete items
6. Delete the table

## Step 1: Launch AWS CloudShell

1. Log in to your AWS account
2. In the AWS Management Console, click the CloudShell icon in the navigation bar at the top

## Step 2: Create a DynamoDB Table

We'll create a `Students` table with a partition key of `StudentID` and a sort key of `CourseID`.

```bash
aws dynamodb create-table \
    --table-name Students \
    --attribute-definitions \
        AttributeName=StudentID,AttributeType=S \
        AttributeName=CourseID,AttributeType=S \
    --key-schema \
        AttributeName=StudentID,KeyType=HASH \
        AttributeName=CourseID,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST
```

Verify the table is being created:

```bash
aws dynamodb describe-table --table-name Students
```

## Step 3: Insert Data into the Table

Let's insert some student records. We'll use the `put-item` command.

### Add first student record:

```bash
aws dynamodb put-item \
    --table-name Students \
    --item '{
        "StudentID": {"S": "S1001"},
        "CourseID": {"S": "CS101"},
        "Name": {"S": "John Smith"},
        "Email": {"S": "john.smith@example.com"},
        "Grade": {"N": "85"},
        "Semester": {"S": "Fall2023"}
    }'
```

### Add more records:

```bash
aws dynamodb put-item \
    --table-name Students \
    --item '{
        "StudentID": {"S": "S1001"},
        "CourseID": {"S": "MATH201"},
        "Name": {"S": "John Smith"},
        "Email": {"S": "john.smith@example.com"},
        "Grade": {"N": "92"},
        "Semester": {"S": "Fall2023"}
    }'
```

```bash
aws dynamodb put-item \
    --table-name Students \
    --item '{
        "StudentID": {"S": "S1002"},
        "CourseID": {"S": "CS101"},
        "Name": {"S": "Jane Doe"},
        "Email": {"S": "jane.doe@example.com"},
        "Grade": {"N": "91"},
        "Semester": {"S": "Fall2023"}
    }'
```

```bash
aws dynamodb put-item \
    --table-name Students \
    --item '{
        "StudentID": {"S": "S1003"},
        "CourseID": {"S": "PHYS101"},
        "Name": {"S": "Bob Johnson"},
        "Email": {"S": "bob.johnson@example.com"},
        "Grade": {"N": "78"},
        "Semester": {"S": "Spring2024"}
    }'
```

```bash
aws dynamodb put-item \
    --table-name Students \
    --item '{
        "StudentID": {"S": "S1002"},
        "CourseID": {"S": "PHYS101"},
        "Name": {"S": "Jane Doe"},
        "Email": {"S": "jane.doe@example.com"},
        "Grade": {"N": "88"},
        "Semester": {"S": "Spring2024"}
    }'
```

## Step 4: Query and Scan the Table

### Scan the entire table:

```bash
aws dynamodb scan --table-name Students
```

### Query for a specific student:

```bash
aws dynamodb query \
    --table-name Students \
    --key-condition-expression "StudentID = :sid" \
    --expression-attribute-values '{":sid": {"S": "S1001"}}'
```

### Query for a specific student in a specific course:

```bash
aws dynamodb query \
    --table-name Students \
    --key-condition-expression "StudentID = :sid AND CourseID = :cid" \
    --expression-attribute-values '{
        ":sid": {"S": "S1001"},
        ":cid": {"S": "CS101"}
    }'
```

## Step 5: Update and Delete Items

### Update a student's grade:

```bash
aws dynamodb update-item \
    --table-name Students \
    --key '{
        "StudentID": {"S": "S1001"},
        "CourseID": {"S": "CS101"}
    }' \
    --update-expression "SET Grade = :g" \
    --expression-attribute-values '{":g": {"N": "90"}}' \
    --return-values ALL_NEW
```

### Delete a student record:

```bash
aws dynamodb delete-item \
    --table-name Students \
    --key '{
        "StudentID": {"S": "S1003"},
        "CourseID": {"S": "PHYS101"}
    }'
```

### Verify the deletion:

```bash
aws dynamodb scan --table-name Students
```

## Step 6: Filter Results with Scan

Let's find all students with grades above 85:

```bash
aws dynamodb scan \
    --table-name Students \
    --filter-expression "Grade > :g" \
    --expression-attribute-values '{":g": {"N": "85"}}'
```

Find all students in the Fall 2023 semester:

```bash
aws dynamodb scan \
    --table-name Students \
    --filter-expression "Semester = :sem" \
    --expression-attribute-values '{":sem": {"S": "Fall2023"}}'
```

## Step 7: Create a Secondary Index

Let's create a Global Secondary Index (GSI) to query by Email:

```bash
aws dynamodb update-table \
    --table-name Students \
    --attribute-definitions AttributeName=Email,AttributeType=S \
    --global-secondary-index-updates '[
        {
            "Create": {
                "IndexName": "EmailIndex",
                "KeySchema": [
                    {"AttributeName": "Email", "KeyType": "HASH"}
                ],
                "Projection": {"ProjectionType": "ALL"},
                "ProvisionedThroughput": {
                    "ReadCapacityUnits": 5,
                    "WriteCapacityUnits": 5
                }
            }
        }
    ]'
```

Query the GSI:

```bash
aws dynamodb query \
    --table-name Students \
    --index-name EmailIndex \
    --key-condition-expression "Email = :e" \
    --expression-attribute-values '{":e": {"S": "jane.doe@example.com"}}'
```

## Step 8: Clean Up Resources

Delete the table when you're done:

```bash
aws dynamodb delete-table --table-name Students
```

## Data Schema

The Students table uses a composite key structure:

- **Partition Key**: StudentID (String)
- **Sort Key**: CourseID (String)

### Additional Attributes:
- Name (String)
- Email (String)
- Grade (Number)
- Semester (String)

## Sample Data

| StudentID | CourseID | Name        | Email                  | Grade | Semester    |
|-----------|----------|-------------|------------------------|-------|-------------|
| S1001     | CS101    | John Smith  | john.smith@example.com | 90    | Fall2023    |
| S1001     | MATH201  | John Smith  | john.smith@example.com | 92    | Fall2023    |
| S1002     | CS101    | Jane Doe    | jane.doe@example.com   | 91    | Fall2023    |
| S1002     | PHYS101  | Jane Doe    | jane.doe@example.com   | 88    | Spring2024  |

## Data Schema Diagram

Here's a simple visualization of the data model:

```
Students Table
+------------+----------+----------+----------------------+-------+------------+
| StudentID  | CourseID | Name     | Email                | Grade | Semester   |
| (Partition)| (Sort)   |          |                      |       |            |
+============+==========+==========+======================+=======+============+
| S1001      | CS101    | John     | john.smith@example   | 90    | Fall2023   |
+------------+----------+----------+----------------------+-------+------------+
| S1001      | MATH201  | John     | john.smith@example   | 92    | Fall2023   |
+------------+----------+----------+----------------------+-------+------------+
| S1002      | CS101    | Jane     | jane.doe@example     | 91    | Fall2023   |
+------------+----------+----------+----------------------+-------+------------+
| S1002      | PHYS101  | Jane     | jane.doe@example     | 88    | Spring2024 |
+------------+----------+----------+----------------------+-------+------------+
```

## Data Access Patterns

This table design supports the following access patterns:

1. Find all courses for a specific student
2. Find a specific student's performance in a specific course
3. Find all students with the same email (via GSI)
4. Find all students in a particular semester (via scan with filter)
5. Find all students with grades above a threshold (via scan with filter)

## Tips for Working with DynamoDB

1. The primary key uniquely identifies each item in the table
2. In our case, the combination of StudentID and CourseID is unique
3. GSIs can help with alternate access patterns
4. Avoid scanning the entire table in production applications
5. Use specific queries whenever possible
