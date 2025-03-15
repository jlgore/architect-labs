resource "null_resource" "load_dynamodb_data" {
  depends_on = [aws_dynamodb_table.students_table]

  # This will run for each item in the student_items list
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for table to be active
      aws dynamodb wait table-exists --table-name Students

      # Load student data
      for item in "${jsonencode(local.student_items)}"; do
        aws dynamodb put-item \
          --table-name Students \
          --item '{
            "StudentID": {"S": "'$${item.StudentID}'"},
            "CourseID": {"S": "'$${item.CourseID}'"},
            "Name": {"S": "'$${item.Name}'"},
            "Email": {"S": "'$${item.Email}'"},
            "Grade": {"N": "'$${item.Grade}'"},
            "Semester": {"S": "'$${item.Semester}'"}
          }'
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
} 