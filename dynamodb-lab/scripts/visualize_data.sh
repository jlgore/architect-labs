#!/bin/bash

echo "=========================================================="
echo "DYNAMODB DATA VISUALIZATION"
echo "=========================================================="
echo ""
echo "What this script does:"
echo "1. Export DynamoDB data to CSV format for visualization"
echo "2. Create a simple ASCII bar chart using gnuplot"
echo "3. This demonstrates how to transform NoSQL data for analysis"
echo ""
echo "Starting data export and visualization..."
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Installing jq..."
    sudo yum install -y jq
fi

echo "Step 1: Exporting DynamoDB data to CSV..."
aws dynamodb scan --table-name Students --output json | \
    jq -r '.Items[] | [.StudentID.S, .CourseID.S, .Grade.N] | @csv' > students.csv

echo ""
echo "Data exported to students.csv"
echo ""

# Check if gnuplot is installed
if ! command -v gnuplot &> /dev/null; then
    echo "gnuplot is required but not installed. Installing gnuplot..."
    sudo yum install -y gnuplot
fi

echo "Step 2: Creating a simple bar chart of student grades..."
echo ""

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

echo ""
echo "Visualization complete. This is a simple ASCII chart of grades."
echo "In a real application, you might use more sophisticated visualization tools."
echo "=========================================================="

# Clean up
rm plot.gnu