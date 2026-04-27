variable "development_database_secret" {
  description = "Database credentials stored in the development namespace Nomad variable. Override via tfvars or TF_VAR_development_database_secret."
  type = object({
    username = string
    password = string
    host     = string
    port     = string
    database = string
  })
  sensitive = true

  default = {
    username = "app_user"
    password = "change-me"
    host     = "db.service.consul"
    port     = "5432"
    database = "myapp"
  }
}

variable "development_api_keys" {
  description = "Example API credentials for the development namespace. Replace these placeholders before using them in real workloads."
  type = object({
    stripe_key     = string
    sendgrid_key   = string
    aws_access_key = string
    aws_secret_key = string
  })
  sensitive = true

  default = {
    stripe_key     = "replace-me"
    sendgrid_key   = "replace-me"
    aws_access_key = "replace-me"
    aws_secret_key = "replace-me"
  }
}

variable "staging_app_secrets" {
  description = "Application secrets stored in the staging namespace Nomad variable."
  type = object({
    jwt_secret  = string
    session_key = string
    admin_email = string
  })
  sensitive = true

  default = {
    jwt_secret  = "replace-me"
    session_key = "replace-me"
    admin_email = "admin@staging.example.invalid"
  }
}

variable "production_app_secrets" {
  description = "Application secrets stored in the production namespace Nomad variable."
  type = object({
    jwt_secret  = string
    session_key = string
    admin_email = string
  })
  sensitive = true

  default = {
    jwt_secret  = "replace-me"
    session_key = "replace-me"
    admin_email = "admin@example.invalid"
  }
}
