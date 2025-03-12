#!/bin/bash
# batch_write_example.sh

# ==========================================================
# BATCH WRITE OPERATIONS IN DYNAMODB
# ==========================================================

# What this script does:
# 1. Demonstrates how to add multiple items in a single API call
# 2. BatchWriteItem can contain up to 25 put or delete requests
# 3. This is much more efficient than individual put-item calls
# 4. We're adding two new students with a single operation

# Running the batch write operation now...

aws dynamodb batch-write-item --request-items '{
    "Students": [
        {
            "PutRequest": {
                "Item": {
                    "StudentID": {"S": "S1004"},
                    "CourseID": {"S": "BIO101"},
                    "Name": {"S": "Maria Garcia"},
                    "Email": {"S": "maria.garcia@example.com"},
                    "Grade": {"N": "94"},
                    "Semester": {"S": "Spring2024"}
                }
            }
        },
        {
            "PutRequest": {
                "Item": {
                    "StudentID": {"S": "S1005"},
                    "CourseID": {"S": "CHEM101"},
                    "Name": {"S": "David Kim"},
                    "Email": {"S": "david.kim@example.com"},
                    "Grade": {"N": "89"},
                    "Semester": {"S": "Spring2024"}
                }
            }
        }
    ]
}'

# Batch write operation complete. Two new students have been added.
# ==========================================================