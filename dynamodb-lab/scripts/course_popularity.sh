#!/bin/bash

echo "=========================================================="
echo "COURSE POPULARITY ANALYSIS"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. First, we scan the entire Students table to get all records"
echo "2. We use jq to extract just the CourseID from each item"
echo "3. We count occurrences of each CourseID using sort and uniq -c"
echo "4. Finally, we sort numerically to find the most popular course"
echo ""
echo "Running the analysis now..."
echo ""

echo "Step 1: Retrieving all course enrollments..."
aws dynamodb scan \
    --table-name Students \
    --projection-expression "CourseID" \
    --output json > course_data.json

echo ""
echo "Step 2: Counting enrollments per course..."
cat course_data.json | jq -r '.Items[].CourseID.S' | sort | uniq -c | sort -nr

echo ""
echo "The course with the highest number appears at the top of the list."
echo "This represents the most popular course based on enrollment count."
echo "=========================================================="

# Clean up temporary file
rm course_data.json