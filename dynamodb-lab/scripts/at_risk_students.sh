#!/bin/bash

# ==========================================================
# FINDING AT-RISK STUDENTS (GRADES BELOW 80)
# ==========================================================

# What this script does:
# 1. We're using a scan operation because we need to check all records
# 2. The filter expression 'Grade < :threshold' finds grades below 80
# 3. We're using a placeholder :threshold defined in expression-attribute-values
# 4. The output is formatted as JSON for readability

# Running the command now...

# Run the scan with filter expression
aws dynamodb scan \
    --table-name Students \
    --filter-expression "Grade < :threshold" \
    --expression-attribute-values '{":threshold": {"N": "80"}}' \
    --output json