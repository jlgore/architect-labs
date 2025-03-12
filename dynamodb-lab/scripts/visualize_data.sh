#!/bin/bash

# ==========================================================
# DYNAMODB DATA VISUALIZATION
# ==========================================================

# What this script does:
# 1. Export DynamoDB data to CSV format for visualization
# 2. Create a simple ASCII bar chart using gnuplot
# 3. This demonstrates how to transform NoSQL data for analysis

# Starting data export and visualization...

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Installing jq..."
    sudo yum install -y jq
fi

# Step 1: Exporting DynamoDB data to CSV...
aws dynamodb scan --table-name Students --output json | \
    jq -r '.Items[] | [.StudentID.S, .CourseID.S, .Grade.N] | @csv' > students.csv

# Data exported to students.csv

# Check if gnuplot is installed
if ! command -v gnuplot &> /dev/null; then
    echo "gnuplot is required but not installed. Installing gnuplot..."
    sudo yum install -y gnuplot
fi

# Step 2: Creating a simple bar chart of student grades...

# Create a gnuplot script
cat > plot.gnu << EOL
set terminal dumb
set title "Student Grades"
set style data histogram
set style fill solid
plot "students.csv" using 3:xtic(1) title "Grades"
EOL

# Run gnuplot
gnuplot plot.gnu

# Visualization complete. This is a simple ASCII chart of grades.
# In a real application, you might use more sophisticated visualization tools.
# ==========================================================

# Clean up
rm plot.gnu