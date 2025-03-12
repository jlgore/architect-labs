# AWS RDS PostgreSQL Lab in CloudShell

This lab will guide you through creating and managing an Amazon RDS PostgreSQL database instance using the AWS CLI within CloudShell. You'll create a custom VPC with a public subnet and configure the necessary networking components to make your RDS instance publicly accessible.

## Prerequisites

- AWS account with access to CloudShell
- Basic understanding of SQL and databases
- Permission to create RDS and VPC resources

## Lab Overview

In this lab, you will:
1. Launch AWS CloudShell
2. Create a custom VPC with a public subnet
3. Configure networking components (Internet Gateway, Route Tables)
4. Create a security group for your RDS instance
5. Create a PostgreSQL RDS database instance
6. Connect to your database
7. Import sample data
8. Query your data
9. Clean up resources

## Step 1: Launch AWS CloudShell

1. Sign in to the AWS Management Console
2. Click on the CloudShell icon in the navigation bar (or search for "CloudShell")
3. Wait for CloudShell to initialize

## Step 2: Create a Custom VPC and Networking Components

Let's set up our networking infrastructure first:

```bash
# Set variables for your VPC and networking components
VPC_NAME="rds-lab-vpc"
VPC_CIDR="10.0.0.0/16"
SUBNET_NAME="rds-public-subnet"
SUBNET_CIDR="10.0.1.0/24"
REGION="us-east-1"  # or whatever region you want to use
AZ="${REGION}a"

# Create a VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query 'Vpc.VpcId' \
    --output text)
echo "VPC created with ID: $VPC_ID"

# Enable DNS hostnames for the VPC
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Create a public subnet
SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_CIDR \
    --availability-zone $AZ \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET_NAME}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Subnet created with ID: $SUBNET_ID"

# Create an Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=rds-lab-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
echo "Internet Gateway created with ID: $IGW_ID"

# Attach the Internet Gateway to the VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

# Create a custom route table
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=rds-lab-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
echo "Route Table created with ID: $ROUTE_TABLE_ID"

# Create a route to the Internet Gateway
aws ec2 create-route \
    --route-table-id $ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Associate the route table with the subnet
aws ec2 associate-route-table \
    --route-table-id $ROUTE_TABLE_ID \
    --subnet-id $SUBNET_ID

# Create a DB subnet group (we need at least 2 subnets in different AZs)
# Create a second subnet in a different AZ
SUBNET2_CIDR="10.0.2.0/24"
AZ2="${REGION}b"  # Use the second availability zone in your region

SUBNET2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET2_CIDR \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=rds-public-subnet-2}]" \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Second subnet created with ID: $SUBNET2_ID"

# Associate the route table with the second subnet
aws ec2 associate-route-table \
    --route-table-id $ROUTE_TABLE_ID \
    --subnet-id $SUBNET2_ID

# Create DB subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name rds-lab-subnet-group \
    --db-subnet-group-description "Subnet group for RDS lab" \
    --subnet-ids '["'$SUBNET_ID'", "'$SUBNET2_ID'"]'
```

## Step 3: Create a Security Group for RDS

Now let's create a security group to allow PostgreSQL traffic:

```bash
# Create a security group for RDS
SG_ID=$(aws ec2 create-security-group \
    --group-name rds-lab-sg \
    --description "Security group for RDS lab" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
echo "Security Group created with ID: $SG_ID"

# Allow PostgreSQL traffic (port 5432) from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5432 \
    --cidr 0.0.0.0/0

# Note: In a production environment, you would restrict this to specific IP addresses
```

## Step 4: Create a PostgreSQL RDS Instance

Now let's create our PostgreSQL database in the custom VPC:

```bash
# Set variables for your database (you can modify these values)
DB_NAME="studentdb"
DB_INSTANCE="student-postgres"
DB_USER="studentadmin"
DB_PASSWORD="ChangeMe123!"  # Remember to use a secure password in real scenarios

# Create RDS instance in the custom VPC
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.12 \
    --allocated-storage 20 \
    --master-username $DB_USER \
    --master-user-password $DB_PASSWORD \
    --db-subnet-group-name rds-lab-subnet-group \
    --vpc-security-group-ids $SG_ID \
    --publicly-accessible \
    --no-multi-az
```

This will take several minutes to complete. You can check the status with:

```bash
# Check the status of your RDS instance
aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --query 'DBInstances[0].DBInstanceStatus'
```

Wait until the status shows `"available"` before proceeding.

## Step 5: Get Connection Information

Once your database is available, retrieve the endpoint:

```bash
# Get the RDS endpoint
aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

Save this endpoint value, you'll need it to connect to your database.

## Step 6: Create a Database and Connect

First, let's install PostgreSQL client and create our database:

```bash
# Install the PostgreSQL client if not already available in CloudShell
sudo yum install -y postgresql15

# Set your endpoint (replace with your actual endpoint from previous step)
ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

# Create a database - connect to the default postgres database first
export PGPASSWORD=$DB_PASSWORD
psql -h $ENDPOINT -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"

# Now you can connect to your new database
psql -h $ENDPOINT -U $DB_USER -d $DB_NAME
```

## Step 7: Download and Import Sample Data

Now let's download and import sample data files:

```bash
# Create a directory for our data files
mkdir -p ~/rds-lab-data

# Download SQL files (or create them locally as shown below)
# Note: These URLs should point to the correct files if they exist in your repository
curl -s https://raw.githubusercontent.com/jlgore/architect-labs/refs/heads/main/rds-lab/students.sql -o ~/rds-lab-data/students.sql
curl -s https://raw.githubusercontent.com/jlgore/architect-labs/refs/heads/main/rds-lab/courses.sql -o ~/rds-lab-data/courses.sql
curl -s https://raw.githubusercontent.com/jlgore/architect-labs/refs/heads/main/rds-lab/enrollments.sql -o ~/rds-lab-data/enrollments.sql

# Import the data files in the correct order (students, courses, then enrollments)
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -f ~/rds-lab-data/students.sql
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -f ~/rds-lab-data/courses.sql
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -f ~/rds-lab-data/enrollments.sql
```

Alternatively, you can create these files locally in CloudShell:

```bash
# Create students.sql file
cat > ~/rds-lab-data/students.sql << 'EOF'
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    enrollment_date DATE NOT NULL,
    major VARCHAR(100),
    gpa NUMERIC(3,2)
);

INSERT INTO students (first_name, last_name, email, enrollment_date, major, gpa) VALUES
('John', 'Doe', 'john.doe@example.com', '2023-01-15', 'Computer Science', 3.75),
('Jane', 'Smith', 'jane.smith@example.com', '2023-02-20', 'Data Science', 3.90),
('Bob', 'Johnson', 'bob.johnson@example.com', '2023-01-10', 'Information Technology', 3.50),
('Emily', 'Davis', 'emily.davis@example.com', '2023-03-05', 'Computer Science', 3.67),
('Michael', 'Wilson', 'michael.wilson@example.com', '2023-02-25', 'Cybersecurity', 3.85),
('Sarah', 'Taylor', 'sarah.taylor@example.com', '2023-01-20', 'Data Science', 3.95),
('David', 'Brown', 'david.brown@example.com', '2023-03-15', 'Software Engineering', 3.70),
('Lisa', 'Anderson', 'lisa.anderson@example.com', '2023-02-10', 'Information Technology', 3.60),
('James', 'Thomas', 'james.thomas@example.com', '2023-01-25', 'Cybersecurity', 3.80),
('Jennifer', 'Jackson', 'jennifer.jackson@example.com', '2023-03-10', 'Software Engineering', 3.78);
EOF

# Create courses.sql file
cat > ~/rds-lab-data/courses.sql << 'EOF'
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code VARCHAR(10) UNIQUE NOT NULL,
    course_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    credits INTEGER NOT NULL,
    professor VARCHAR(100)
);

INSERT INTO courses (course_code, course_name, department, credits, professor) VALUES
('CS101', 'Introduction to Programming', 'Computer Science', 3, 'Dr. Alan Turing'),
('CS201', 'Data Structures and Algorithms', 'Computer Science', 4, 'Dr. Ada Lovelace'),
('DATA301', 'Introduction to Data Science', 'Data Science', 3, 'Dr. Claude Shannon'),
('IT150', 'Database Management', 'Information Technology', 3, 'Dr. Grace Hopper'),
('CS350', 'Operating Systems', 'Computer Science', 4, 'Dr. Linus Torvalds'),
('SEC200', 'Cybersecurity Fundamentals', 'Cybersecurity', 3, 'Dr. Dorothy Vaughan'),
('SE400', 'Software Engineering Principles', 'Software Engineering', 4, 'Dr. Margaret Hamilton'),
('DATA420', 'Machine Learning', 'Data Science', 4, 'Dr. Geoffrey Hinton'),
('IT300', 'Cloud Computing', 'Information Technology', 3, 'Dr. Ken Thompson'),
('CS450', 'Artificial Intelligence', 'Computer Science', 4, 'Dr. Fei-Fei Li');
EOF

# Create enrollments.sql file
cat > ~/rds-lab-data/enrollments.sql << 'EOF'
CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(student_id),
    course_id INTEGER REFERENCES courses(course_id),
    enrollment_date DATE NOT NULL,
    grade VARCHAR(2),
    UNIQUE(student_id, course_id)
);

INSERT INTO enrollments (student_id, course_id, enrollment_date, grade) VALUES
(1, 1, '2023-01-20', 'A'),
(1, 2, '2023-01-20', 'B+'),
(2, 3, '2023-02-25', 'A'),
(2, 8, '2023-02-25', 'A-'),
(3, 4, '2023-01-15', 'B'),
(3, 9, '2023-01-15', 'A-'),
(4, 1, '2023-03-10', 'A'),
(4, 5, '2023-03-10', 'B+'),
(5, 6, '2023-03-01', 'A-'),
(5, 10, '2023-03-01', 'A'),
(6, 3, '2023-01-25', 'A+'),
(6, 8, '2023-01-25', 'A'),
(7, 7, '2023-03-20', 'B+'),
(7, 2, '2023-03-20', 'A-'),
(8, 4, '2023-02-15', 'B+'),
(8, 9, '2023-02-15', 'A-'),
(9, 6, '2023-01-30', 'A'),
(9, 10, '2023-01-30', 'A-'),
(10, 7, '2023-03-15', 'A'),
(10, 3, '2023-03-15', 'A-');
EOF
```

## Step 8: Query Your Database

Let's run some basic queries to explore our data:

```bash
# Query all students
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "SELECT * FROM students;"

# Count students by major
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT major, COUNT(*) AS student_count 
FROM students 
GROUP BY major 
ORDER BY student_count DESC;"

# Find courses with the highest average grades
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT c.course_code, c.course_name, AVG(
    CASE 
        WHEN e.grade = 'A+' THEN 4.00
        WHEN e.grade = 'A' THEN 4.00
        WHEN e.grade = 'A-' THEN 3.67
        WHEN e.grade = 'B+' THEN 3.33
        WHEN e.grade = 'B' THEN 3.00
        WHEN e.grade = 'B-' THEN 2.67
        ELSE 0
    END) AS avg_gpa
FROM courses c
JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_code, c.course_name
ORDER BY avg_gpa DESC;"
```

## Step 9: More Advanced Queries

Let's try some more advanced queries using joins:

```bash
# List all students with their enrolled courses
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT s.first_name, s.last_name, c.course_code, c.course_name, e.grade
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
JOIN courses c ON e.course_id = c.course_id
ORDER BY s.last_name, s.first_name, c.course_code;"

# Find the most popular courses (most enrollments)
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT c.course_code, c.course_name, COUNT(*) AS enrollment_count
FROM courses c
JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_code, c.course_name
ORDER BY enrollment_count DESC;"

# Find students with the highest GPA in each major
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT major, first_name, last_name, gpa
FROM (
    SELECT s.major, s.first_name, s.last_name, s.gpa,
           RANK() OVER (PARTITION BY s.major ORDER BY s.gpa DESC) as rank
    FROM students s
) ranked
WHERE rank = 1
ORDER BY major;"
```

## Understanding the Queries

Here's a breakdown of some key SQL queries used in this lab:

### Basic SELECT Query

```sql
SELECT * FROM students;
```

This is the most basic query:
- `SELECT` specifies which columns you want to retrieve
- `*` is a wildcard meaning "all columns"
- `FROM students` indicates which table to query
- The semicolon `;` marks the end of the SQL statement

### Aggregation with GROUP BY

```sql
SELECT major, COUNT(*) AS student_count 
FROM students 
GROUP BY major 
ORDER BY student_count DESC;
```

This query counts students by major:
- `SELECT major` selects the major column
- `COUNT(*)` counts the number of rows in each group
- `AS student_count` renames the count column to "student_count"
- `GROUP BY major` groups the results by the major field
- `ORDER BY student_count DESC` sorts the results in descending order by the count

### CASE Statement for Grade Conversion

```sql
SELECT c.course_code, c.course_name, AVG(
    CASE 
        WHEN e.grade = 'A+' THEN 4.00
        WHEN e.grade = 'A' THEN 4.00
        WHEN e.grade = 'A-' THEN 3.67
        WHEN e.grade = 'B+' THEN 3.33
        WHEN e.grade = 'B' THEN 3.00
        WHEN e.grade = 'B-' THEN 2.67
        ELSE 0
    END) AS avg_gpa
FROM courses c
JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_code, c.course_name
ORDER BY avg_gpa DESC;
```

This query calculates the average GPA for each course:
- The `CASE` statement works like an if/else statement, converting letter grades to numeric values
- `AVG()` calculates the average of those numeric values
- `FROM courses c` uses "c" as an alias for the courses table
- `JOIN enrollments e ON c.course_id = e.course_id` connects the courses and enrollments tables
- `GROUP BY` groups the results by course
- `ORDER BY avg_gpa DESC` sorts by highest average GPA first

### JOINs for Related Data

```sql
SELECT s.first_name, s.last_name, c.course_code, c.course_name, e.grade
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
JOIN courses c ON e.course_id = c.course_id
ORDER BY s.last_name, s.first_name, c.course_code;
```

This query connects data from three tables:
- `FROM students s` starts with the students table (aliased as "s")
- `JOIN enrollments e ON s.student_id = e.student_id` connects students to their enrollments
- `JOIN courses c ON e.course_id = c.course_id` connects enrollments to course information
- The result shows each student with their enrolled courses and grades
- `ORDER BY` sorts the results by last name, first name, and course code

### Window Functions with RANK()

```sql
SELECT major, first_name, last_name, gpa
FROM (
    SELECT s.major, s.first_name, s.last_name, s.gpa,
           RANK() OVER (PARTITION BY s.major ORDER BY s.gpa DESC) as rank
    FROM students s
) ranked
WHERE rank = 1
ORDER BY major;
```

This is a more advanced query using window functions:
- The inner query uses `RANK() OVER (PARTITION BY s.major ORDER BY s.gpa DESC)` to rank students within each major by GPA
- `PARTITION BY s.major` divides the data into groups by major
- `ORDER BY s.gpa DESC` ranks students with highest GPA first
- The outer query filters to only show rank 1 students (the top student in each major)
- This gives us the student with the highest GPA in each major

## Step 10: Modify Database Configuration

You can modify certain settings of your RDS instance:

```bash
# Increase storage capacity to 25GB
aws rds modify-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --allocated-storage 25 \
    --apply-immediately

# Create a DB snapshot before making further changes (good practice)
aws rds create-db-snapshot \
    --db-snapshot-identifier $DB_INSTANCE-snapshot \
    --db-instance-identifier $DB_INSTANCE
```

## Step 11: Clean Up Resources

When you're done with the lab, clean up to avoid ongoing charges:

```bash
# Delete the RDS instance (skip the final snapshot for this lab)
aws rds delete-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --skip-final-snapshot

# Wait for the RDS instance to be deleted before deleting other resources
echo "Waiting for RDS instance to be deleted..."
aws rds wait db-instance-deleted --db-instance-identifier $DB_INSTANCE

# Delete the security group
aws ec2 delete-security-group --group-id $SG_ID

# Delete the DB subnet group
aws rds delete-db-subnet-group --db-subnet-group-name rds-lab-subnet-group

# Detach the internet gateway from the VPC
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Delete the internet gateway
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# Delete the route table
aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID

# Delete the subnets
aws ec2 delete-subnet --subnet-id $SUBNET_ID
aws ec2 delete-subnet --subnet-id $SUBNET2_ID

# Delete the VPC
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## Challenge Section: School Database Challenges

Imagine you're working as a database administrator for a local high school. The school has recently migrated their student information system to AWS RDS PostgreSQL, and they need your help to create reports and implement new features. Complete the following challenges to help the school make the most of their database.

### Challenge 1: Student Performance Analysis

The school principal needs to identify students who might need academic support.

```bash
# Write a query to find students with an average grade below B (3.0 GPA) across all courses
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT s.student_id, s.first_name, s.last_name, 
       AVG(CASE 
           WHEN e.grade = 'A+' THEN 4.00
           WHEN e.grade = 'A' THEN 4.00
           WHEN e.grade = 'A-' THEN 3.67
           WHEN e.grade = 'B+' THEN 3.33
           WHEN e.grade = 'B' THEN 3.00
           WHEN e.grade = 'B-' THEN 2.67
           WHEN e.grade = 'C+' THEN 2.33
           WHEN e.grade = 'C' THEN 2.00
           ELSE 0
       END) AS avg_grade
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
GROUP BY s.student_id, s.first_name, s.last_name
HAVING AVG(CASE 
           WHEN e.grade = 'A+' THEN 4.00
           WHEN e.grade = 'A' THEN 4.00
           WHEN e.grade = 'A-' THEN 3.67
           WHEN e.grade = 'B+' THEN 3.33
           WHEN e.grade = 'B' THEN 3.00
           WHEN e.grade = 'B-' THEN 2.67
           WHEN e.grade = 'C+' THEN 2.33
           WHEN e.grade = 'C' THEN 2.00
           ELSE 0
       END) < 3.0
ORDER BY avg_grade;"
```

**What happens in this query?**
- The query joins the students and enrollments tables
- It uses a CASE statement to convert letter grades to numeric values
- The AVG function calculates each student's average grade
- The HAVING clause filters to only show students with averages below 3.0
- Results are ordered by average grade (lowest first)

### Challenge 2: Department Workload Report

The academic dean needs a report on department workloads to allocate resources for the next semester.

```bash
# Create a report showing each department's total credits, number of courses, and average class size
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
WITH course_enrollments AS (
    SELECT c.course_id, c.department, c.credits, COUNT(e.student_id) AS num_students
    FROM courses c
    LEFT JOIN enrollments e ON c.course_id = e.course_id
    GROUP BY c.course_id, c.department, c.credits
)
SELECT 
    department,
    COUNT(*) AS num_courses,
    SUM(credits) AS total_credits,
    ROUND(AVG(num_students), 2) AS avg_class_size
FROM course_enrollments
GROUP BY department
ORDER BY total_credits DESC;"
```

**What happens in this query?**
- The query uses a Common Table Expression (CTE) to first calculate enrollment counts for each course
- It then aggregates this data by department
- The COUNT function determines how many courses each department offers
- SUM calculates the total credits across all courses in each department
- AVG calculates the average class size (number of students)
- Results are ordered by total credits (highest first)

### Challenge 3: Create a Stored Function

The registrar's office needs a function to calculate letter grades based on numeric scores.

```bash
# Create a function to convert numeric scores to letter grades
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
CREATE OR REPLACE FUNCTION calculate_letter_grade(score NUMERIC) 
RETURNS VARCHAR(2) AS $$
BEGIN
    IF score >= 97 THEN
        RETURN 'A+';
    ELSIF score >= 93 THEN
        RETURN 'A';
    ELSIF score >= 90 THEN
        RETURN 'A-';
    ELSIF score >= 87 THEN
        RETURN 'B+';
    ELSIF score >= 83 THEN
        RETURN 'B';
    ELSIF score >= 80 THEN
        RETURN 'B-';
    ELSIF score >= 77 THEN
        RETURN 'C+';
    ELSIF score >= 73 THEN
        RETURN 'C';
    ELSIF score >= 70 THEN
        RETURN 'C-';
    ELSIF score >= 67 THEN
        RETURN 'D+';
    ELSIF score >= 63 THEN
        RETURN 'D';
    ELSIF score >= 60 THEN
        RETURN 'D-';
    ELSE
        RETURN 'F';
    END IF;
END;
$$ LANGUAGE plpgsql;"

# Test the function with some sample scores
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT 
    score,
    calculate_letter_grade(score) AS letter_grade
FROM (VALUES (98), (95), (91), (88), (85), (81), (78), (75), (71), (68), (65), (61), (55)) AS t(score);"
```

**What happens when creating this function?**
- The CREATE OR REPLACE FUNCTION statement defines a new PostgreSQL function
- The function takes a numeric score as input and returns a letter grade
- It uses IF/ELSIF/ELSE logic to determine the appropriate grade based on score ranges
- The LANGUAGE plpgsql specifies that we're using PostgreSQL's procedural language
- The test query demonstrates how the function works with various scores

### Challenge 4: Create a View for Academic Advisors

Academic advisors need a comprehensive view of student information for advising sessions.

```bash
# Create a view that combines student information with their course enrollments and grades
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
CREATE OR REPLACE VIEW student_academic_profile AS
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    s.email,
    s.major,
    s.gpa AS overall_gpa,
    c.course_code,
    c.course_name,
    c.credits,
    e.grade,
    e.enrollment_date
FROM 
    students s
LEFT JOIN 
    enrollments e ON s.student_id = e.student_id
LEFT JOIN 
    courses c ON e.course_id = c.course_id
ORDER BY 
    s.last_name, s.first_name, c.course_code;"

# Query the view to see a specific student's profile
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT * FROM student_academic_profile WHERE student_id = 1;"
```

**What happens when creating this view?**
- The CREATE OR REPLACE VIEW statement creates a virtual table that doesn't store data itself
- The view joins data from students, enrollments, and courses tables
- It provides a comprehensive profile of each student's academic information
- When queried, the view executes its underlying query and returns the results
- This simplifies complex queries for advisors who need this information regularly

### Challenge 5: Database Triggers for Audit Logging

The school needs to track changes to student records for compliance purposes.

```bash
# First, create an audit table
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
CREATE TABLE IF NOT EXISTS student_audit_log (
    log_id SERIAL PRIMARY KEY,
    action VARCHAR(10) NOT NULL,
    student_id INTEGER NOT NULL,
    changed_by VARCHAR(50) NOT NULL,
    change_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_data JSONB,
    new_data JSONB
);"

# Create a trigger function
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
CREATE OR REPLACE FUNCTION log_student_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO student_audit_log(action, student_id, changed_by, old_data, new_data)
        VALUES('DELETE', OLD.student_id, current_user, row_to_json(OLD)::jsonb, NULL);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO student_audit_log(action, student_id, changed_by, old_data, new_data)
        VALUES('UPDATE', NEW.student_id, current_user, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO student_audit_log(action, student_id, changed_by, old_data, new_data)
        VALUES('INSERT', NEW.student_id, current_user, NULL, row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;"

# Create the trigger
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
CREATE TRIGGER student_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW EXECUTE FUNCTION log_student_changes();"

# Test the trigger by updating a student record
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
UPDATE students SET gpa = 3.95 WHERE student_id = 1;"

# Check the audit log
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
SELECT * FROM student_audit_log;"
```

**What happens with this trigger setup?**
- We first create an audit_log table to store change history
- The trigger function captures the type of change (INSERT, UPDATE, DELETE)
- It stores both the old and new values when appropriate
- The trigger is set to fire AFTER any change to the students table
- When a student record is modified, the change is automatically logged
- This provides a complete audit trail for compliance and troubleshooting

### Bonus Challenge: Database Performance Optimization

The database is experiencing slow query performance as the number of students and courses grows.

#### Understanding Database Indexes

A database index is a data structure that improves the speed of data retrieval operations on a database table. Think of it like the index at the back of a textbook - instead of scanning through the entire book to find information on a specific topic, you can look up the topic in the index and go directly to the relevant pages.

**How indexes work:**
- Indexes create a separate data structure that contains only the indexed columns and pointers to the corresponding table rows
- When you query an indexed column, the database can quickly find the matching values in the index
- The database then uses the pointers to retrieve the complete rows from the table
- Without indexes, the database would need to scan every row in the table (a "full table scan")

**Benefits of indexes:**
- Dramatically faster query performance for large tables
- Improved efficiency for JOIN operations
- Better performance for ORDER BY and GROUP BY operations
- Enforcement of uniqueness constraints (with UNIQUE indexes)

**Potential drawbacks:**
- Indexes require additional storage space
- Write operations (INSERT, UPDATE, DELETE) become slightly slower because indexes must be updated
- Inappropriate indexes can sometimes decrease performance

1. Create appropriate indexes to improve query performance:

```bash
# Create indexes on frequently queried columns
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
-- Index for student lookups by email
CREATE INDEX idx_students_email ON students(email);

-- Index for course lookups by code
CREATE INDEX idx_courses_code ON courses(course_code);

-- Index for enrollments lookups
CREATE INDEX idx_enrollments_student ON enrollments(student_id);
CREATE INDEX idx_enrollments_course ON enrollments(course_id);"
```

**What happens when creating these indexes?**
- The `CREATE INDEX` statement builds a new index on the specified column
- PostgreSQL scans the table and builds a sorted data structure for the indexed column
- The `idx_students_email` index will speed up queries that filter or join on the email column
- The foreign key indexes (`idx_enrollments_student` and `idx_enrollments_course`) improve JOIN performance
- Each index is named with a prefix (`idx_`) to clearly identify it as an index

2. Analyze the database to update statistics for the query planner:

```bash
# Analyze the database to improve query planning
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "
ANALYZE students;
ANALYZE courses;
ANALYZE enrollments;"
```

## Troubleshooting

If you encounter connection issues:
- Check that your RDS security group allows inbound connections on port 5432 (PostgreSQL default port)
- Verify you're using the correct endpoint, username, and password
- Ensure your CloudShell session has network connectivity to the RDS instance
- Verify that the route table is correctly associated with your subnets
- Check that the Internet Gateway is properly attached to your VPC

## Additional Notes

- In a production environment, you would never hardcode passwords in scripts
- For production workloads, it's best practice to place RDS instances in private subnets
- The security group in this lab allows access from any IP (0.0.0.0/0) which is not recommended for production
- For a real application, consider using parameter groups, option groups, and proper backup strategies
- PostgreSQL offers many advanced features like stored procedures, triggers, and custom data types that are beyond the scope of this lab

# Connect to your database and drop the tables in the correct order
# First drop enrollments (which references students and courses)
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS enrollments;"

# Then drop courses
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS courses;"

# Finally drop students
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS students;"

# Amazon RDS PostgreSQL Guide

This guide provides instructions for connecting to and working with Amazon RDS PostgreSQL instances.

## Connection Information

To connect to your PostgreSQL database instance, you'll need the following information:

- **Endpoint**: Your RDS instance endpoint (e.g., `mydb.cxyz123abc.us-east-1.rds.amazonaws.com`)
- **Port**: Default PostgreSQL port is 5432
- **Database name**: Your database name (default is often "postgres")
- **Username**: Master username you configured when creating the instance
- **Password**: Master password you configured when creating the instance

## Connecting via Command Line

### Setting Environment Variables

For convenience, you can set environment variables for your connection parameters:

```bash
export ENDPOINT="your-rds-endpoint.region.rds.amazonaws.com"
export DB_USER="your_master_username"
export DB_NAME="your_database_name"
export DB_PASSWORD="your_password"
```

### Basic Connection

Connect to your PostgreSQL database using the `psql` command-line client:

```bash
psql -h $ENDPOINT -U $DB_USER -d $DB_NAME
```

When prompted, enter your password.

### Connection with Password in Command

If you prefer to include the password in the connection command (not recommended for production):

```bash
PGPASSWORD=$DB_PASSWORD psql -h $ENDPOINT -U $DB_USER -d $DB_NAME
```

### Connection with Additional Options

```bash
psql -h $ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -W
```

The `-W` flag explicitly prompts for a password.

## Common PostgreSQL Commands

Once connected to your PostgreSQL database, you can use these common commands:

```sql
-- List all databases
\l

-- Connect to a specific database
\c database_name

-- List all tables in the current database
\dt

-- Describe a table structure
\d table_name

-- Execute a SQL query
SELECT * FROM table_name LIMIT 10;

-- Create a new table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert data
INSERT INTO users (username, email) VALUES ('johndoe', 'john@example.com');

-- Exit the PostgreSQL shell
\q
```

## Troubleshooting Connection Issues

If you encounter connection issues:

1. Verify your security group allows inbound traffic on port 5432
2. Check that your database instance is publicly accessible (if connecting from outside VPC)
3. Confirm your credentials are correct
4. Ensure your database instance is in the "Available" state

## Backup and Restore

### Creating a Backup

```bash
pg_dump -h $ENDPOINT -U $DB_USER -d $DB_NAME > backup.sql
```

### Restoring from a Backup

```bash
psql -h $ENDPOINT -U $DB_USER -d $DB_NAME < backup.sql
```

## Monitoring

Monitor your RDS instance performance through:
- Amazon RDS Console
- Amazon CloudWatch
- PostgreSQL's built-in monitoring: `SELECT * FROM pg_stat_activity;`


