-- Courses table creation and data

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
('CS450', 'Artificial Intelligence', 'Computer Science', 4, 'Dr. Fei-Fei Li'),
('CS275', 'Web Development', 'Computer Science', 3, 'Dr. Tim Berners-Lee'),
('DATA350', 'Big Data Analytics', 'Data Science', 4, 'Dr. Hadley Wickham'),
('IT250', 'Network Administration', 'Information Technology', 3, 'Dr. Vint Cerf'),
('SEC300', 'Ethical Hacking', 'Cybersecurity', 4, 'Dr. Bruce Schneier'),
('SE450', 'Agile Development', 'Software Engineering', 3, 'Dr. Kent Beck'),
('CS425', 'Computer Graphics', 'Computer Science', 4, 'Dr. Edwin Catmull'),
('DATA425', 'Natural Language Processing', 'Data Science', 4, 'Dr. Andrew Ng'),
('IT350', 'IT Project Management', 'Information Technology', 3, 'Dr. Frederick Brooks'),
('SEC350', 'Network Security', 'Cybersecurity', 4, 'Dr. Whitfield Diffie'),
('SE425', 'DevOps and Continuous Integration', 'Software Engineering', 3, 'Dr. Martin Fowler');
