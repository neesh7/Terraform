resource "local_file" "pet" {
  filename = var.filenames[count.index] # pet[0] → pets.txt, pet[1] → dogs.txt, etc.
  content  = var.content
  #   count    = 2                      # Creates 3 resources
  count = length(var.filenames)
}