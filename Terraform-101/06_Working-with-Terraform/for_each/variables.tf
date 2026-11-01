variable "filename" {
  type = list(string)
  default = ["/root/pets.txt",
    "/root/cows.txt",
  "/root/cats.txt"]
}
variable "content" {
  default = "This is a pet file"
}