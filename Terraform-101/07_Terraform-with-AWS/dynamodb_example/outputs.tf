output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.example_table.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.example_table.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.example_table.id
}

output "hash_key" {
  description = "Partition key name"
  value       = aws_dynamodb_table.example_table.hash_key
}

output "range_key" {
  description = "Sort key name (if any)"
  value       = var.range_key != "" ? var.range_key : "None"
}

output "billing_mode" {
  description = "Table billing mode"
  value       = var.billing_mode
}

output "read_capacity_units" {
  description = "Read capacity units (PROVISIONED mode)"
  value       = var.billing_mode == "PROVISIONED" ? var.read_capacity_units : "N/A (On-demand)"
}

output "write_capacity_units" {
  description = "Write capacity units (PROVISIONED mode)"
  value       = var.billing_mode == "PROVISIONED" ? var.write_capacity_units : "N/A (On-demand)"
}

output "pitr_enabled" {
  description = "Point-In-Time Recovery status"
  value       = aws_dynamodb_table.example_table.point_in_time_recovery_specification[0].enabled
}

output "encryption_enabled" {
  description = "Server-side encryption status"
  value       = aws_dynamodb_table.example_table.server_side_encryption_specification[0].enabled
}

output "ttl_enabled" {
  description = "TTL (Time To Live) status"
  value       = var.ttl_attribute_name != "" ? "Enabled (${var.ttl_attribute_name})" : "Disabled"
}

output "gsi_created" {
  description = "Whether Global Secondary Index was created"
  value       = var.create_gsi ? "Yes - ${var.table_name}-gsi" : "No"
}

output "table_status" {
  description = "Current table status"
  value       = aws_dynamodb_table.example_table.table_status
}
