# ─────────────────────────────────────────────
# Variable Types in Terraform — Examples
# ─────────────────────────────────────────────

# 1. String variable — simple text value
variable "filename" {
  type        = string
  default     = "/root/pets.txt"
  description = "Path of the file to be created"
}

# 2. String variable with no default — must be provided at runtime
variable "runtimecontent" {
  type        = string
  description = "Content to write into the file"
}
variable "content" {
  type        = string
  default = "we love pets"
  description = "Content to write into the file"
}

# 3. Number variable
variable "length" {
  type        = number
  default     = 2
  description = "Number of words in the random pet name"
}

# 4. Bool variable
variable "enable_logging" {
  type        = bool
  default     = false
  description = "Toggle to enable or disable logging"
}

# 5. List variable — ordered collection of same type
variable "prefix_list" {
  type        = list(string)
  default     = ["Mr", "Mrs", "Dr"]
  description = "List of prefixes to pick from"
}

# 6. Map variable — key/value pairs
variable "file_permissions" {
  type = map(string)
  default = {
    "pets.txt"  = "0700"
    "creds.txt" = "0400"
  }
  description = "File permission map per filename"
}

# 7. Set variable — unordered collection, no duplicate values
variable "allowed_ports" {
  type        = set(number)
  default     = [22, 80, 443]
  description = "Set of allowed network ports — duplicates are automatically removed"
}

# 8. Object variable — structured, mixed types
variable "pet_config" {
  type = object({
    name      = string
    age       = number
    vaccinated = bool
  })
  default = {
    name       = "Whiskers"
    age        = 3
    vaccinated = true
  }
  description = "Structured config for a pet"
}

# 9. Tuple variable — ordered, mixed types (fixed length)
variable "pet_details" {
  type        = tuple([string, number, bool])
  default     = ["cat", 5, true]
  description = "Tuple of pet name, age, and vaccination status"
}
variable "prefix" {
  default = "MR."
  type = string
  
}
variable "separator" {
  default = "."
  type = string
  
}