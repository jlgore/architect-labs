-- Students table creation and data

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
('Jennifer', 'Jackson', 'jennifer.jackson@example.com', '2023-03-10', 'Software Engineering', 3.78),
('Alex', 'Martinez', 'alex.martinez@example.com', '2023-02-05', 'Computer Science', 3.45),
('Michelle', 'Lee', 'michelle.lee@example.com', '2023-01-30', 'Data Science', 3.88),
('Daniel', 'White', 'daniel.white@example.com', '2023-03-20', 'Information Technology', 3.62),
('Laura', 'Harris', 'laura.harris@example.com', '2023-02-15', 'Cybersecurity', 3.75),
('Christopher', 'Clark', 'christopher.clark@example.com', '2023-01-05', 'Software Engineering', 3.83),
('Jessica', 'Lewis', 'jessica.lewis@example.com', '2023-03-25', 'Computer Science', 3.91),
('Matthew', 'Walker', 'matthew.walker@example.com', '2023-02-28', 'Data Science', 3.65),
('Amanda', 'Hall', 'amanda.hall@example.com', '2023-01-18', 'Information Technology', 3.52),
('Andrew', 'Young', 'andrew.young@example.com', '2023-03-12', 'Cybersecurity', 3.79),
('Olivia', 'Allen', 'olivia.allen@example.com', '2023-02-08', 'Software Engineering', 3.87);
