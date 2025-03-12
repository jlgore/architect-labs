#!/bin/bash
# lsi_example.sh

# ==========================================================
# LOCAL SECONDARY INDEX (LSI) IN DYNAMODB
# ==========================================================

# What this script does:
# 1. Creates a new table with a Local Secondary Index on Grade
# 2. LSIs must be created when the table is created (unlike GSIs)
# 3. LSIs share the same partition key as the base table
# 4. This allows efficient queries to find courses by grade within a student

# Step 1: Creating a new table with an LSI...

aws dynamodb create-table \
    --table-name StudentsWithLSI \
    --attribute-definitions \
        AttributeName=StudentID,AttributeType=S \
        AttributeName=CourseID,AttributeType=S \
        AttributeName=Grade,AttributeType=N \
    --key-schema \
        AttributeName=StudentID,KeyType=HASH \
        AttributeName=CourseID,KeyType=RANGE \
    --local-secondary-indexes '[
        {
            "IndexName": "GradeIndex",
            "KeySchema": [
                {"AttributeName": "StudentID", "KeyType": "HASH"},
                {"AttributeName": "Grade", "KeyType": "RANGE"}
            ],
            "Projection": {"ProjectionType": "ALL"}
        }
    ]' \
    --billing-mode PAY_PER_REQUEST

# Waiting for table creation to complete...
sleep 10

# Step 2: Adding sample data to the new table...
aws dynamodb batch-write-item --request-items '{
    "StudentsWithLSI": [
        {
            "PutRequest": {
                "Item": {
                    "StudentID": {"S": "S1001"},
                    "CourseID": {"S": "CS101"},
                    "Name": {"S": "John Smith"},
                    "Grade": {"N": "85"}
                }
            }
        },
        {
            "PutRequest": {
                "Item": {
                    "StudentID": {"S": "S1001"},
                    "CourseID": {"S": "MATH201"},
                    "Name": {"S": "John Smith"},
                    "Grade": {"N": "92"}
                }
            }
        },
        {
            "PutRequest": {
                "Item": {
                    "StudentID": {"S": "S1001"},
                    "CourseID": {"S": "PHYS101"},
                    "Name": {"S": "John Smith"},
                    "Grade": {"N": "78"}
                }
            }
        }
    ]
}'

# Step 3: Querying the LSI to find courses ordered by grade...

# This query will return all of John's courses, sorted by grade (highest first):
aws dynamodb query \
    --table-name StudentsWithLSI \
    --index-name GradeIndex \
    --key-condition-expression "StudentID = :sid" \
    --expression-attribute-values '{":sid": {"S": "S1001"}}' \
    --scan-index-forward false \
    --return-consumed-capacity TOTAL

# LSI demonstration complete. Notice how the results are ordered by grade.
# This is useful for finding a student's best or worst performing courses.
# ==========================================================