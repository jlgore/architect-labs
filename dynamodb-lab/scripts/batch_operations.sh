#!/bin/bash
# batch_write_example.sh

echo "=========================================================="
echo "BATCH WRITE OPERATIONS IN DYNAMODB"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. Demonstrates how to add multiple items in a single API call"
echo "2. BatchWriteItem can contain up to 25 put or delete requests"
echo "3. This is much more efficient than individual put-item calls"
echo "4. We're adding two new students with a single operation"
echo ""
echo "Running the batch write operation now..."
echo ""

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

echo ""
echo "Batch write operation complete. Two new students have been added."
echo "=========================================================="