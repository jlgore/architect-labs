#!/bin/bash

echo "=========================================================="
echo "FINDING AT-RISK STUDENTS (GRADES BELOW 80)"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. We're using a scan operation because we need to check all records"
echo "2. The filter expression 'Grade < :threshold' finds grades below 80"
echo "3. We're using a placeholder :threshold defined in expression-attribute-values"
echo "4. The output is formatted as JSON for readability"
echo ""
echo "Running the command now..."
echo ""

# Run the scan with filter expression
aws dynamodb scan \
    --table-name Students \
    --filter-expression "Grade < :threshold" \
    --expression-attribute-values '{":threshold": {"N": "80"}}' \
    --output json

echo ""
echo "Command completed. These students may need academic support."
echo "=========================================================="