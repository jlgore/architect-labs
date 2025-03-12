#!/bin/bash

# ==========================================================
# COURSE POPULARITY ANALYSIS
# ==========================================================

# What this script does:
# 1. First, we scan the entire Students table to get all records
# 2. We use jq to extract just the CourseID from each item
# 3. We count occurrences of each CourseID using sort and uniq -c
# 4. Finally, we sort numerically to find the most popular course

# Running the analysis now...

# Step 1: Retrieving all course enrollments...
aws dynamodb scan \
    --table-name Students \
    --projection-expression "CourseID" \
    --output json > course_data.json

# Step 2: Counting enrollments per course...
cat course_data.json | jq -r '.Items[].CourseID.S' | sort | uniq -c | sort -nr

# The course with the highest number appears at the top of the list.
# This represents the most popular course based on enrollment count.
# ==========================================================

# Clean up temporary file
rm course_data.json