output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.example_bucket.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.example_bucket.arn
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.example_bucket.region
}

output "bucket_domain_name" {
  description = "Bucket domain name for accessing objects"
  value       = aws_s3_bucket.example_bucket.bucket_regional_domain_name
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket"
  value       = aws_s3_bucket_versioning.example_versioning.versioning_configuration[0].status
}

output "encryption_type" {
  description = "Server-side encryption type"
  value       = "AES256"
}

output "bucket_access" {
  description = "Public access status"
  value       = "Blocked (secure)"
}
