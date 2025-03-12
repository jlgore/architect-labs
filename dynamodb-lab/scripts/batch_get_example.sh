#!/bin/bash
# batch_get_example.sh

# ==========================================================
# BATCH GET OPERATIONS IN DYNAMODB
# ==========================================================

# What this script does:
# 1. Demonstrates how to retrieve multiple items in a single API call
# 2. BatchGetItem can retrieve items from multiple tables
# 3. Each item is identified by its complete primary key
# 4. We're retrieving two specific student records efficiently

# Running the batch get operation now...

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

# Batch get operation complete. Retrieved multiple items with one API call.
# ==========================================================