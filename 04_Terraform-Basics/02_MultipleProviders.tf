# This file uses two providers at once — local and random.

# Provider: hashicorp/local — manages files on the local filesystem
resource "local_file" "pet" {
    # filename = "/root/pets.txt" 
    filename = "pets.txt"  # path where the file will be created
    content  = "We love pets" # text written into the file
}

# Provider: hashicorp/random — generates random values (no real infra created)
resource "random_pet" "my-pet" {
    prefix    = "Mrs"  # prepended to the generated name e.g. "Mrs.wolf"
    separator = "."    # character between prefix and the pet name
    length    = "1"    # number of random words to generate
}