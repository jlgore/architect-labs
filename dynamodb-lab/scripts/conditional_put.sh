#!/bin/bash
# conditional_put.sh

# ==========================================================
# CONDITIONAL PUT OPERATIONS IN DYNAMODB
# ==========================================================

# What this script does:
# 1. Demonstrates how to add an item only if it doesn't already exist
# 2. We'll add a new course for a student only if they don't already have it
# 3. This prevents accidentally overwriting existing course data
# 4. The attribute_not_exists function checks if the item exists

# Running the conditional put operation now...

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

# If you see a ConditionalCheckFailedException, it means the student
# is already enrolled in this course. Otherwise, the enrollment was added.
# ==========================================================