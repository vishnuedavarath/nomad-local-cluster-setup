# =============================================================================
# Outputs
# =============================================================================

output "nomad_ui_url" {
  description = "Nomad UI URL."
  value       = module.cluster.nomad_address
}

output "consul_ui_url" {
  description = "Consul UI URL."
  value       = module.cluster.consul_address
}

output "nomad_addr_export" {
  description = "Shell export for NOMAD_ADDR."
  value       = "export NOMAD_ADDR=${module.cluster.nomad_address}"
}

output "server_ips" {
  description = "Server VM IPs."
  value       = module.instances.server_ips
}

output "client_ips" {
  description = "Client VM IPs."
  value       = module.instances.client_ips
}

output "server_names" {
  description = "Server VM names."
  value       = module.instances.server_names
}

output "client_names" {
  description = "Client VM names."
  value       = module.instances.client_names
}

output "acl_bootstrap_token" {
  description = "Nomad ACL bootstrap token."
  value       = module.cluster.acl_bootstrap_token
  sensitive   = true
}

output "nomad_token_export" {
  description = "Shell export for NOMAD_TOKEN (uses ops token for day-to-day operations)."
  value       = var.enable_acl ? "export NOMAD_TOKEN=${length(module.acl) > 0 ? module.acl[0].ops_token : module.cluster.acl_bootstrap_token}" : "# ACL disabled"
  sensitive   = true
}

output "nomad_version" {
  description = "Installed Nomad version."
  value       = module.cluster.nomad_release_version
}

output "acl_bootstrapped" {
  description = "Whether ACL bootstrap has completed."
  value       = module.cluster.acl_bootstrapped
}

output "ops_token" {
  description = "Ops token for day-to-day cluster operations (full namespace/node/volume write access)."
  value       = length(module.acl) > 0 ? module.acl[0].ops_token : null
  sensitive   = true
}

output "admin_token" {
  description = "Admin management token (use sparingly, for ACL management only)."
  value       = length(module.acl) > 0 ? module.acl[0].admin_token : null
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL (if enabled)."
  value       = length(module.oidc) > 0 ? module.oidc[0].dex_issuer_url : null
}
