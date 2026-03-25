output "nomad_address_used" {
  description = "The Nomad address used from cluster state"
  value       = local.nomad_address
}

output "nomad_addr_export" {
  description = "Shell export command for NOMAD_ADDR"
  value       = "export NOMAD_ADDR=${local.nomad_address}"
}

output "nomad_admin_token_export" {
  description = "Shell export command for NOMAD_TOKEN using the admin ACL token"
  sensitive   = true
  value       = "export NOMAD_TOKEN=${nomad_acl_token.admin.secret_id}"
}
