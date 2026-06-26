variable "db_name" {
  default = "gitops_db"
}

variable "db_username" {
  default = "postgres"
}

variable "db_password" {
  description = "Postgres password"
  sensitive   = true
}