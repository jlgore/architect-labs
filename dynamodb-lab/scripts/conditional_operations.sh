#!/bin/bash
# conditional_update.sh

echo "=========================================================="
echo "CONDITIONAL UPDATE OPERATIONS IN DYNAMODB"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. Demonstrates how to update an item only if a condition is met"
echo "2. We'll update a student's grade only if it's currently below 90"
echo "3. This prevents overwriting higher grades accidentally"
echo "4. The condition-expression parameter enforces this rule"
echo ""
echo "Running the conditional update operation now..."
echo ""

aws dynamodb update-item \
    --table-name Students \
    --key '{
        "StudentID": {"S": "S1003"},
        "CourseID": {"S": "PHYS101"}
    }' \
    --update-expression "SET Grade = :newgrade" \
    --condition-expression "Grade < :threshold" \
    --expression-attribute-values '{
        ":newgrade": {"N": "82"},
        ":threshold": {"N": "90"}
    }' \
    --return-values ALL_NEW

echo ""
echo "If you see a ConditionalCheckFailedException, it means the condition wasn't met."
echo "Otherwise, the grade was updated because it was below the threshold."
echo "=========================================================="