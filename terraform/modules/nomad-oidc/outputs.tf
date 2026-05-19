output "dex_issuer_url" {
  description = "OIDC issuer URL."
  value       = local.dex_issuer_url
}

output "dex_discovery_url" {
  description = "OIDC discovery document URL."
  value       = "${local.dex_issuer_url}/.well-known/openid-configuration"
}

output "dex_client_id" {
  description = "OIDC client ID."
  value       = var.dex_client_id
}

output "dex_client_secret" {
  description = "OIDC client secret."
  value       = random_password.dex_client_secret.result
  sensitive   = true
}

output "dex_runtime" {
  description = "Where Dex is running."
  value       = var.dex_runtime
}

output "auth_method_name" {
  description = "Name of the created Nomad ACL auth method (if created)."
  value       = var.create_auth_method ? nomad_acl_auth_method.dex[0].name : null
}

output "nomad_login_command" {
  description = "CLI command to login via OIDC."
  value       = var.create_auth_method ? "nomad login -method=${var.auth_method_name} -oidc-callback-addr=localhost:4649" : null
}
