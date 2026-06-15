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

# Create admin user
resource "aws_iam_user" "admin" {
  name = "admin-user"

  tags = {
    Role        = "Administrator"
    Environment = "Production"
  }
}

# Create admin policy (referencing external file)
resource "aws_iam_policy" "admin_policy" {
  name        = "AdminPolicy"
  description = "Full administrator access"
  policy      = file("${path.module}/policies/admin_policy.json")
}

# Attach admin policy to admin user
resource "aws_iam_user_policy_attachment" "admin_access" {
  user       = aws_iam_user.admin.name
  policy_arn = aws_iam_policy.admin_policy.arn
}

# Create developer user
resource "aws_iam_user" "developer" {
  name = "dev-user"

  tags = {
    Role        = "Developer"
    Environment = "Development"
  }
}

# Create S3 read-only policy (referencing external file)
resource "aws_iam_policy" "s3_read_only_policy" {
  name        = "S3ReadOnlyPolicy"
  description = "Read-only access to S3 buckets"
  policy      = file("${path.module}/policies/s3_read_only_policy.json")
}

# Attach S3 policy to developer user
resource "aws_iam_user_policy_attachment" "dev_s3_access" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.s3_read_only_policy.arn
}

# Create DynamoDB developer user
resource "aws_iam_user" "dynamodb_developer" {
  name = "dynamodb-dev-user"

  tags = {
    Role        = "DynamoDB Developer"
    Environment = "Development"
  }
}

# Create DynamoDB policy (referencing external file)
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "DynamoDBDeveloperPolicy"
  description = "Full access to DynamoDB"
  policy      = file("${path.module}/policies/dynamodb_policy.json")
}

# Attach DynamoDB policy to DynamoDB developer user
resource "aws_iam_user_policy_attachment" "dynamodb_dev_access" {
  user       = aws_iam_user.dynamodb_developer.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}
