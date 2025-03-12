#!/bin/bash

echo "=========================================================="
echo "SEMESTER TRANSITION: UPDATING FALL2023 TO COMPLETED STATUS"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. First, we scan to find all items with Semester = Fall2023"
echo "2. For each item found, we perform an update operation"
echo "3. We add a new Status attribute with value 'Completed'"
echo "4. This demonstrates updating multiple items based on a condition"
echo ""
echo "Running the semester transition now..."
echo ""

# First, find all Fall2023 items
echo "Step 1: Finding all Fall2023 semester entries..."
FALL_ITEMS=$(aws dynamodb scan \
    --table-name Students \
    --filter-expression "Semester = :sem" \
    --expression-attribute-values '{":sem": {"S": "Fall2023"}}' \
    --output json)

# Extract the keys of each item
echo ""
echo "Step 2: Extracting keys for each Fall2023 entry..."
STUDENT_COURSES=$(echo $FALL_ITEMS | jq -r '.Items[] | "\(.StudentID.S)|\(.CourseID.S)"')

# Update each item
echo ""
echo "Step 3: Updating each entry with 'Completed' status..."
for ITEM in $STUDENT_COURSES; do
    IFS='|' read -r STUDENT_ID COURSE_ID <<< "$ITEM"
    echo "Updating $STUDENT_ID in $COURSE_ID to Completed status..."
    
    aws dynamodb update-item \
        --table-name Students \
        --key "{\"StudentID\": {\"S\": \"$STUDENT_ID\"}, \"CourseID\": {\"S\": \"$COURSE_ID\"}}" \
        --update-expression "SET #status = :s" \
        --expression-attribute-names '{"#status": "Status"}' \
        --expression-attribute-values '{":s": {"S": "Completed"}}' \
        --return-values UPDATED_NEW
done

echo ""
echo "Semester transition complete. All Fall2023 entries now have Completed status."
echo "=========================================================="