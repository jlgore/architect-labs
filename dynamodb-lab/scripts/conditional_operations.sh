#!/bin/bash
# conditional_update.sh

# ==========================================================
# CONDITIONAL UPDATE OPERATIONS IN DYNAMODB
# ==========================================================

# What this script does:
# 1. Demonstrates how to update an item only if a condition is met
# 2. We'll update a student's grade only if it's currently below 90
# 3. This prevents overwriting higher grades accidentally
# 4. The condition-expression parameter enforces this rule

# Running the conditional update operation now...

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

# If you see a ConditionalCheckFailedException, it means the condition wasn't met.
# Otherwise, the grade was updated because it was below the threshold.
# ==========================================================