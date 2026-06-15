variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
  default     = "my-terraform-bucket-12345"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_versioning" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "upload_sample_file" {
  description = "Whether to upload a sample file to the bucket"
  type        = bool
  default     = false
}
