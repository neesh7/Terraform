terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create S3 bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = "Terraform"
  }
}

# Enable versioning on the bucket
resource "aws_s3_bucket_versioning" "example_versioning" {
  bucket = aws_s3_bucket.example_bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Block public access to the bucket (security best practice)
resource "aws_s3_bucket_public_access_block" "example_pab" {
  bucket = aws_s3_bucket.example_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "example_encryption" {
  bucket = aws_s3_bucket.example_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload a sample file to the bucket (optional)
resource "aws_s3_object" "sample_file" {
  count   = var.upload_sample_file ? 1 : 0
  bucket  = aws_s3_bucket.example_bucket.id
  key     = "sample.txt"
  content = "This is a sample file uploaded by Terraform"

  tags = {
    Description = "Sample file"
  }
}
