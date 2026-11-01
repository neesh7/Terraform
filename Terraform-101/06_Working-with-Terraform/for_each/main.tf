# variable "filename" {
#   type = set(string)
#   default = [ "/root/pets.txt",
#               "/root/cows.txt",
#               "/root/cats.txt"   ]
# }

# resource "local_file" "pet" {
#   filename = each.value
#   for_each = var.filename
# }

# Note : for_each works with sets and map only.

# or if we still want to pass string then we have to handle it at loop end by performing toset conversion


resource "local_file" "pet" {
  filename = each.value
  content  = var.content
  for_each = toset(var.filename)
}
# Using for_each we create output as map but with count it's a list which is index dependent
output "pets" {
  value     = local_file.pet
  sensitive = true
}