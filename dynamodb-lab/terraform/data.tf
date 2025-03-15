# This file will contain sample data to be loaded into DynamoDB
# We'll use local-exec provisioner to load the data after table creation

locals {
  student_items = [
    {
      StudentID = "S1001"
      CourseID  = "CS101"
      Name      = "John Smith"
      Email     = "john.smith@example.com"
      Grade     = 85
      Semester  = "Fall2023"
    },
    {
      StudentID = "S1001"
      CourseID  = "MATH201"
      Name      = "John Smith"
      Email     = "john.smith@example.com"
      Grade     = 92
      Semester  = "Fall2023"
    },
    {
      StudentID = "S1002"
      CourseID  = "CS101"
      Name      = "Jane Doe"
      Email     = "jane.doe@example.com"
      Grade     = 91
      Semester  = "Fall2023"
    },
    {
      StudentID = "S1003"
      CourseID  = "PHYS101"
      Name      = "Bob Johnson"
      Email     = "bob.johnson@example.com"
      Grade     = 78
      Semester  = "Spring2024"
    },
    {
      StudentID = "S1002"
      CourseID  = "PHYS101"
      Name      = "Jane Doe"
      Email     = "jane.doe@example.com"
      Grade     = 88
      Semester  = "Spring2024"
    }
  ]
} 