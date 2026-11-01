variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "terraform-table"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "billing_mode" {
  description = "Billing mode: PAY_PER_REQUEST or PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "hash_key" {
  description = "Partition key attribute name"
  type        = string
  default     = "id"
}

variable "range_key" {
  description = "Sort key attribute name (leave empty for no range key)"
  type        = string
  default     = ""
}

variable "read_capacity_units" {
  description = "Read capacity units (for PROVISIONED billing)"
  type        = number
  default     = 5
}

variable "write_capacity_units" {
  description = "Write capacity units (for PROVISIONED billing)"
  type        = number
  default     = 5
}

variable "enable_pitr" {
  description = "Enable Point-In-Time Recovery for backups"
  type        = bool
  default     = true
}

variable "ttl_attribute_name" {
  description = "TTL attribute name for auto-deletion (leave empty to disable)"
  type        = string
  default     = ""
}

variable "create_gsi" {
  description = "Whether to create a Global Secondary Index"
  type        = bool
  default     = false
}

variable "gsi_partition_key" {
  description = "Partition key for Global Secondary Index"
  type        = string
  default     = "email"
}

variable "gsi_sort_key" {
  description = "Sort key for Global Secondary Index (leave empty for no sort key)"
  type        = string
  default     = ""
}

variable "gsi_read_capacity_units" {
  description = "Read capacity units for GSI (PROVISIONED mode)"
  type        = number
  default     = 5
}

variable "gsi_write_capacity_units" {
  description = "Write capacity units for GSI (PROVISIONED mode)"
  type        = number
  default     = 5
}
