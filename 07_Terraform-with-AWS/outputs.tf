# Admin User Outputs
output "admin_user_name" {
  description = "Name of the admin user"
  value       = aws_iam_user.admin.name
}

output "admin_user_arn" {
  description = "ARN of the admin user"
  value       = aws_iam_user.admin.arn
}

output "admin_policy_arn" {
  description = "ARN of the admin policy"
  value       = aws_iam_policy.admin_policy.arn
}

# Developer User Outputs
output "developer_user_name" {
  description = "Name of the developer user"
  value       = aws_iam_user.developer.name
}

output "developer_user_arn" {
  description = "ARN of the developer user"
  value       = aws_iam_user.developer.arn
}

output "s3_policy_arn" {
  description = "ARN of the S3 read-only policy"
  value       = aws_iam_policy.s3_read_only_policy.arn
}

# DynamoDB Developer User Outputs
output "dynamodb_developer_user_name" {
  description = "Name of the DynamoDB developer user"
  value       = aws_iam_user.dynamodb_developer.name
}

output "dynamodb_developer_user_arn" {
  description = "ARN of the DynamoDB developer user"
  value       = aws_iam_user.dynamodb_developer.arn
}

output "dynamodb_policy_arn" {
  description = "ARN of the DynamoDB policy"
  value       = aws_iam_policy.dynamodb_policy.arn
}
