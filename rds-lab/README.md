# AWS RDS PostgreSQL Lab in CloudShell

This lab will guide you through creating and managing an Amazon RDS PostgreSQL database instance using the AWS CLI within CloudShell. This lab is designed for users with limited permissions (no IAM role creation).

## Prerequisites

- AWS account with access to CloudShell
- Basic understanding of SQL and databases
- Permission to create RDS resources

## Lab Overview

In this lab, you will:
1. Launch AWS CloudShell
2. Create a PostgreSQL RDS database instance
3. Connect to your database
4. Import sample data
5. Query your data
6. Clean up resources

## Step 1: Launch AWS CloudShell

1. Sign in to the AWS Management Console
2. Click on the CloudShell icon in the navigation bar (or search for "CloudShell")
3. Wait for CloudShell to initialize

## Step 2: Create a PostgreSQL RDS Instance

Let's create a simple PostgreSQL database. We'll use the most basic configuration to keep things simple.

```bash
# Set variables for your database (you can modify these values)
DB_NAME="studentdb"
DB_INSTANCE="student-postgres"
DB_USER="studentadmin"
DB_PASSWORD="ChangeMe123!"  # Remember to use a secure password in real scenarios

# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 17.3 \
    --allocated-storage 20 \
    --master-username $DB_USER \
    --master-user-password $DB_PASSWORD \
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

## Step 3: Get Connection Information

Once your database is available, retrieve the endpoint:

```bash
# Get the RDS endpoint
aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

Save this endpoint value, you'll need it to connect to your database.

## Step 4: Create a Database and Connect

First, let's install PostgreSQL client and create our database:

```bash
# Install the PostgreSQL client if not already available in CloudShell
sudo yum install -y postgresql15

# Set your endpoint (replace with your actual endpoint from previous step)
ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

# Create a database
export PGPASSWORD=$DB_PASSWORD 
psql -h $ENDPOINT -U $DB_USER -c "CREATE DATABASE $DB_NAME;"
```

## Step 5: Download and Import Sample Data

Now let's download and import sample data files:

```bash
# Create a directory for our data files
mkdir -p ~/rds-lab-data

# Download student data
curl -s https://raw.githubusercontent.com/sample-data/students.sql -o ~/rds-lab-data/students.sql
curl -s https://raw.githubusercontent.com/sample-data/courses.sql -o ~/rds-lab-data/courses.sql
curl -s https://raw.githubusercontent.com/sample-data/enrollments.sql -o ~/rds-lab-data/enrollments.sql

# Note: The URLs above are placeholders. We'll create these files in the next steps.

# Import the data files
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

## Step 6: Query Your Database

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

## Step 7: More Advanced Queries

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

## Step 8: Modify Database Configuration

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

## Step 9: Clean Up Resources

When you're done with the lab, clean up to avoid ongoing charges:

```bash
# Delete the RDS instance (skip the final snapshot for this lab)
aws rds delete-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --skip-final-snapshot
```

## Challenge Activities

For students who finish early:
1. Create a view that shows each student's average grade across all courses
2. Create a function that calculates GPA based on letter grades
3. Write a query to find courses where the average grade is above B+
4. Create a report showing department statistics (number of courses, average credits, etc.)

## Troubleshooting

If you encounter connection issues:
- Check that your RDS security group allows inbound connections on port 5432 (PostgreSQL default port)
- Verify you're using the correct endpoint, username, and password
- Ensure your CloudShell session has network connectivity to the RDS instance

## Additional Notes

- In a production environment, you would never hardcode passwords in scripts
- The RDS instance created in this lab is not encrypted and is publicly accessible, which is not recommended for production
- For a real application, consider using parameter groups, option groups, and proper backup strategies
- PostgreSQL offers many advanced features like stored procedures, triggers, and custom data types that are beyond the scope of this lab


