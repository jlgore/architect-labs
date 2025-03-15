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

# Add headers to the CSV file for better plotting
echo '"StudentID","CourseID","Grade"' > students_with_header.csv
cat students.csv >> students_with_header.csv

# Check if gnuplot is installed
if ! command -v gnuplot &> /dev/null; then
    echo "gnuplot is required but not installed. Installing gnuplot..."
    sudo yum install -y gnuplot
    
    # Wait for installation to complete and verify gnuplot is available
    if command -v gnuplot &> /dev/null; then
        echo "gnuplot installation successful."
    else
        echo "Failed to install gnuplot. Skipping visualization step."
        # Clean up and exit
        rm students_with_header.csv
        exit 1
    fi
fi

# Step 2: Creating a simple bar chart of student grades...
# Create a more robust gnuplot script
cat > plot.gnu << EOL
set terminal dumb
set title "Student Grades"
set datafile separator ","
set style data histogram
set style fill solid
set xtics rotate by -45
set key off
plot "students_with_header.csv" using 3:xtic(2) with boxes
EOL

# Run gnuplot with error handling
echo "Generating ASCII chart of student grades..."
if gnuplot plot.gnu; then
    echo "Chart generation successful."
else
    echo "Failed to generate chart. Please check if gnuplot is properly installed."
fi

# Visualization complete. This is a simple ASCII chart of grades.
# In a real application, you might use more sophisticated visualization tools.
# ==========================================================

# Clean up
rm plot.gnu students_with_header.csv