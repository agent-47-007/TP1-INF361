variable "group_name" {
  description = "Nom du groupe Linux à créer"
  type        = string
  default     = "students-inf-361"
}

variable "script_path" {
  description = "Chemin vers le script Bash"
  type        = string
  default     = "../part1-bash/create_users.sh"
}

variable "users_file" {
  description = "Chemin vers le fichier des utilisateurs"
  type        = string
  default     = "../part1-bash/users.txt"
}
