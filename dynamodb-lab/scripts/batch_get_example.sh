#!/bin/bash
# batch_get_example.sh

echo "=========================================================="
echo "BATCH GET OPERATIONS IN DYNAMODB"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. Demonstrates how to retrieve multiple items in a single API call"
echo "2. BatchGetItem can retrieve items from multiple tables"
echo "3. Each item is identified by its complete primary key"
echo "4. We're retrieving two specific student records efficiently"
echo ""
echo "Running the batch get operation now..."
echo ""

aws dynamodb batch-get-item --request-items '{
    "Students": {
        "Keys": [
            {
                "StudentID": {"S": "S1001"},
                "CourseID": {"S": "CS101"}
            },
            {
                "StudentID": {"S": "S1002"},
                "CourseID": {"S": "PHYS101"}
            }
        ]
    }
}'

echo ""
echo "Batch get operation complete. Retrieved multiple items with one API call."
echo "=========================================================="