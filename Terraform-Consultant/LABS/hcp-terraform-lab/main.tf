# Creates a Python "Hello World" script.
# NOTE: WHERE this file appears depends on the workspace's Execution Mode:
#   - Remote (default): created on HCP Terraform's disposable worker, NOT your laptop
#   - Local           : created in this folder on your machine
resource "local_file" "hello_py" {
  filename        = "${path.module}/${var.file_name}"
  file_permission = "0755"

  content = <<-EOT
    #!/usr/bin/env python3

    def main():
        print("Hello, I'm Neesh!")
        print("${var.message}")


    if __name__ == "__main__":
        main()
  EOT
}
