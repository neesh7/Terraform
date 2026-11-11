output "file_path" {
  description = "Path of the generated Python file"
  value       = local_file.hello_py.filename
}

output "file_sha256" {
  description = "SHA256 of the file content (changes when the content changes)"
  value       = local_file.hello_py.content_sha256
}

output "run_command" {
  description = "Command to run the script"
  value       = "python ${local_file.hello_py.filename}"
}
