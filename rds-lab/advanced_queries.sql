-- Advanced PostgreSQL queries for student database

-- Get student course load (number of courses per student)
SELECT s.student_id, s.first_name, s.last_name, COUNT(*) AS course_load
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
GROUP BY s.student_id, s.first_name, s.last_name
ORDER BY course_load DESC;

-- Calculate GPA for each student based on enrolled courses
SELECT 
    s.student_id, 
    s.first_name, 
    s.last_name, 
    s.major,
    ROUND(AVG(
        CASE 
            WHEN e.grade = 'A+' THEN 4.00
            WHEN e.grade = 'A' THEN 4.00
            WHEN e.grade = 'A-' THEN 3.67
            WHEN e.grade = 'B+' THEN 3.33
            WHEN e.grade = 'B' THEN 3.00
            WHEN e.grade = 'B-' THEN 2.67
            ELSE 0
        END
    ), 2) AS calculated_gpa
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
GROUP BY s.student_id, s.first_name, s.last_name, s.major
ORDER BY calculated_gpa DESC;

-- Find departments with the highest average grades
SELECT 
    c.department, 
    ROUND(AVG(
        CASE 
            WHEN e.grade = 'A+' THEN 4.00
            WHEN e.grade = 'A' THEN 4.00
            WHEN e.grade = 'A-' THEN 3.67
            WHEN e.grade = 'B+' THEN 3.33
            WHEN e.grade = 'B' THEN 3.00
            WHEN e.grade = 'B-' THEN 2.67
            ELSE 0
        END
    ), 2) AS dept_avg_gpa,
    COUNT(DISTINCT c.course_id) AS course_count
FROM courses c
JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.department
ORDER BY dept_avg_gpa DESC;

-- Find students who are taking courses across multiple departments
SELECT 
    s.student_id, 
    s.first_name, 
    s.last_name, 
    COUNT(DISTINCT c.department) AS department_count,
    string_agg(DISTINCT c.department, ', ') AS departments
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
JOIN courses c ON e.course_id = c.course_id
GROUP BY s.student_id, s.first_name, s.last_name
HAVING COUNT(DISTINCT c.department) > 1
ORDER BY department_count DESC, s.last_name, s.first_name;

-- Professor course load and average student grade
SELECT 
    c.professor, 
    COUNT(DISTINCT c.course_id) AS course_count,
    COUNT(e.enrollment_id) AS total_students,
    ROUND(AVG(
        CASE 
            WHEN e.grade = 'A+' THEN 4.00
            WHEN e.grade = 'A' THEN 4.00
            WHEN e.grade = 'A-' THEN 3.67
            WHEN e.grade = 'B+' THEN 3.33
            WHEN e.grade = 'B' THEN 3.00
            WHEN e.grade = 'B-' THEN 2.67
            ELSE 0
        END
    ), 2) AS avg_student_grade
FROM courses c
JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.professor
ORDER BY avg_student_grade DESC;

-- Create a GPA calculation function
CREATE OR REPLACE FUNCTION calculate_gpa(letter_grade VARCHAR)
RETURNS NUMERIC AS $$
BEGIN
    RETURN CASE 
        WHEN letter_grade = 'A+' THEN 4.00
        WHEN letter_grade = 'A' THEN 4.00
        WHEN letter_grade = 'A-' THEN 3.67
        WHEN letter_grade = 'B+' THEN 3.33
        WHEN letter_grade = 'B' THEN 3.00
        WHEN letter_grade = 'B-' THEN 2.67
        WHEN letter_grade = 'C+' THEN 2.33
        WHEN letter_grade = 'C' THEN 2.00
        WHEN letter_grade = 'C-' THEN 1.67
        WHEN letter_grade = 'D+' THEN 1.33
        WHEN letter_grade = 'D' THEN 1.00
        WHEN letter_grade = 'F' THEN 0.00
        ELSE 0.00
    END;
END;
$$ LANGUAGE plpgsql;

-- Create a student transcript view
CREATE OR REPLACE VIEW student_transcripts AS
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    s.email,
    s.major,
    c.course_code,
    c.course_name,
    c.credits,
    e.grade,
    calculate_gpa(e.grade) AS grade_points
FROM 
    students s
JOIN 
    enrollments e ON s.student_id = e.student_id
JOIN 
    courses c ON e.course_id = c.course_id
ORDER BY 
    s.student_id, c.course_code;

-- Query the transcript view
SELECT * FROM student_transcripts WHERE student_id = 1;
