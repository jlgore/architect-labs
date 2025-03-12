#!/bin/bash
# conditional_put.sh

echo "=========================================================="
echo "CONDITIONAL PUT OPERATIONS IN DYNAMODB"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. Demonstrates how to add an item only if it doesn't already exist"
echo "2. We'll add a new course for a student only if they don't already have it"
echo "3. This prevents accidentally overwriting existing course data"
echo "4. The attribute_not_exists function checks if the item exists"
echo ""
echo "Running the conditional put operation now..."
echo ""

aws dynamodb put-item \
    --table-name Students \
    --item '{
        "StudentID": {"S": "S1001"},
        "CourseID": {"S": "BIO101"},
        "Name": {"S": "John Smith"},
        "Email": {"S": "john.smith@example.com"},
        "Grade": {"N": "88"},
        "Semester": {"S": "Spring2024"}
    }' \
    --condition-expression "attribute_not_exists(CourseID)"

echo ""
echo "If you see a ConditionalCheckFailedException, it means the student"
echo "is already enrolled in this course. Otherwise, the enrollment was added."
echo "=========================================================="