resource "local_file" "my_file" {
    filename = "Automate.txt"
    content = "GenAI is great"
}
resource "local_sensitive_file" "my_creds" {
    filename = "creds.txt"
    content  = <<-EOT
        mail: xyg@zmail.com
        pass: xtfukkk123nn
    EOT
}