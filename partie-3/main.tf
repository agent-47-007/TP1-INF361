terraform {
  required_version = ">= 1.0"
}

provider "null" {}

resource "null_resource" "create_users" {

  provisioner "local-exec" {
    command = <<EOT
      echo "===== Lancement du script de création des utilisateurs ====="
      sudo bash ${var.script_path} ${var.group_name}
    EOT
  }

  triggers = {
    script_checksum = filesha256(var.script_path)
    users_checksum  = filesha256(var.users_file)
  }
}
