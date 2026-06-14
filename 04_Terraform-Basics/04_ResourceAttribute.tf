# Generates a random pet name e.g. "MR.happy-tiger"
# random_pet.pet.id holds the generated name — used by local_file below
resource "random_pet" "pet" {
    prefix    = var.prefix     # prepended to the pet name
    separator = var.separator  # character between prefix and name
    length    = var.length     # number of random words in the name
}

# Creates a local file whose content references the random pet name above
# ${random_pet.pet.id} is an interpolation — Terraform replaces it with
# the actual generated value at apply time, creating an implicit dependency
# so random_pet is always created before this file
resource "local_file" "my-pet" {
    filename = var.filename
    content  = "My favourite pet is ${random_pet.pet.id}"
    # depends_on = [ random_pet.my-pet ] # explicit dependency
}

# Basically output from one resource is use in another resource inputs