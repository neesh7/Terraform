variable "file_name" {
  description = "Name of the Python file to create"
  type        = string
  default     = "hello.py"

  validation {
    condition     = endswith(var.file_name, ".py")
    error_message = "file_name must end with .py"
  }
}

variable "message" {
  description = "Message the Python script prints"
  type        = string
  default     = "Hello, World!"
}
