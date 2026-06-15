variable "filename" {
  description = "Path to the file to be created"
  type        = string
  default     = "random.txt"
}

variable "permission" {
  description = "File permissions (Unix octal notation)"
  type        = string
  default     = "0644"
}

variable "length" {
  description = "Length of the random string to generate"
  type        = number
  default     = 10
}
