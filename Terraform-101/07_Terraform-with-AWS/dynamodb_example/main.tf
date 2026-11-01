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

# Create DynamoDB table
resource "aws_dynamodb_table" "example_table" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = var.hash_key
  range_key      = var.range_key != "" ? var.range_key : null

  # Hash key attribute
  attribute {
    name = var.hash_key
    type = "S"  # S = String, N = Number, B = Binary
  }

  # Range key attribute (optional)
  dynamic "attribute" {
    for_each = var.range_key != "" ? [1] : []
    content {
      name = var.range_key
      type = "S"
    }
  }

  # Provisioned capacity (only used if billing_mode is PROVISIONED)
  dynamic "throughput" {
    for_each = var.billing_mode == "PROVISIONED" ? [1] : []
    content {
      read_capacity_units  = var.read_capacity_units
      write_capacity_units = var.write_capacity_units
    }
  }

  # Enable point-in-time recovery (backup)
  point_in_time_recovery_specification {
    enabled = var.enable_pitr
  }

  # Enable encryption at rest
  server_side_encryption_specification {
    enabled = true
  }

  # Enable TTL (Time To Live) for automatic item deletion
  dynamic "ttl" {
    for_each = var.ttl_attribute_name != "" ? [1] : []
    content {
      attribute_name = var.ttl_attribute_name
      enabled        = true
    }
  }

  tags = {
    Name        = var.table_name
    Environment = var.environment
    Project     = "Terraform"
  }
}

# Create Global Secondary Index (GSI) for additional query patterns
resource "aws_dynamodb_table_gsi" "example_gsi" {
  count = var.create_gsi ? 1 : 0

  name            = "${var.table_name}-gsi"
  hash_key        = var.gsi_partition_key
  range_key       = var.gsi_sort_key != "" ? var.gsi_sort_key : null
  table_name      = aws_dynamodb_table.example_table.name
  projection_type = "ALL"

  # Capacity for PROVISIONED billing
  dynamic "throughput" {
    for_each = var.billing_mode == "PROVISIONED" ? [1] : []
    content {
      read_capacity_units  = var.gsi_read_capacity_units
      write_capacity_units = var.gsi_write_capacity_units
    }
  }
}
