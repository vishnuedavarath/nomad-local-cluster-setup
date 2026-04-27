output "dex_issuer_url" {
  description = "OIDC discovery base URL for the local Dex provider."
  value       = local.dex_issuer_url
}

output "dex_runtime" {
  description = "Where Dex is running."
  value       = var.dex_runtime
}

output "dex_host_access_ip" {
  description = "IP address that Nomad VMs should use to reach Dex when it runs on the host."
  value       = local.host_access_ip
}

output "dex_discovery_url" {
  description = "Full OIDC discovery document URL for the local Dex provider."
  value       = "${local.dex_issuer_url}/.well-known/openid-configuration"
}

output "dex_identity_vm" {
  description = "Selected Nomad client VM used either to host Dex in vm mode or to infer the host-reachable gateway in host mode."
  value = {
    name = local.identity_client_name
    ip   = local.identity_client_ip
  }
}

output "oidc_admin_email" {
  description = "Email for the built-in Dex admin user."
  value       = var.oidc_admin_email
}

output "oidc_admin_password" {
  description = "Password for the built-in Dex admin user."
  value       = local.dex_password
  sensitive   = true
}

output "dex_client_id" {
  description = "OIDC client ID configured in Dex for Nomad."
  value       = local.dex_client_id
}

output "dex_client_secret" {
  description = "OIDC client secret configured in Dex for Nomad."
  value       = random_password.dex_client_secret.result
  sensitive   = true
}

output "nomad_acl_auth_method_inputs" {
  description = "Structured values to pass into a separate nomad_acl_auth_method resource."
  value = {
    name              = var.auth_method_name
    type              = "OIDC"
    token_locality    = "global"
    max_token_ttl     = var.auth_method_max_token_ttl
    token_name_format = "$${auth_method_type}-$${value.email}"
    default           = var.make_default_auth_method
    config = {
      oidc_discovery_url    = local.dex_issuer_url
      oidc_client_id        = local.dex_client_id
      oidc_client_secret    = random_password.dex_client_secret.result
      oidc_disable_userinfo = true
      oidc_enable_pkce      = true
      oidc_scopes           = ["openid", "profile", "email"]
      bound_audiences       = [local.dex_client_id]
      allowed_redirect_uris = local.allowed_redirect_uris
      claim_mappings = {
        email              = "email"
        preferred_username = "username"
      }
    }
  }
  sensitive = true
}

output "nomad_acl_binding_rule_management_inputs" {
  description = "Structured values to pass into a separate nomad_acl_binding_rule resource for the local admin user."
  value = {
    auth_method = var.auth_method_name
    description = "Grant Nomad management access to the local Dex admin user"
    selector    = "value.email == \"${var.oidc_admin_email}\""
    bind_type   = "management"
    bind_name   = ""
  }
}

output "nomad_acl_auth_method_hcl" {
  description = "Ready-to-copy HCL snippet for a separate nomad_acl_auth_method resource."
  value       = <<-EOT
resource "nomad_acl_auth_method" "dex" {
  name              = "${var.auth_method_name}"
  type              = "OIDC"
  token_locality    = "global"
  max_token_ttl     = "${var.auth_method_max_token_ttl}"
  token_name_format = "$${auth_method_type}-$${value.email}"
  default           = ${tostring(var.make_default_auth_method)}

  config {
    oidc_discovery_url    = "${local.dex_issuer_url}"
    oidc_client_id        = "${local.dex_client_id}"
    oidc_client_secret    = "${random_password.dex_client_secret.result}"
    oidc_disable_userinfo = true
    oidc_enable_pkce      = true
    oidc_scopes           = ["openid", "profile", "email"]
    bound_audiences       = ["${local.dex_client_id}"]
    allowed_redirect_uris = ${jsonencode(local.allowed_redirect_uris)}
    claim_mappings = {
      email              = "email"
      preferred_username = "username"
    }
  }
}
  EOT
  sensitive   = true
}

output "nomad_acl_binding_rule_management_hcl" {
  description = "Ready-to-copy HCL snippet for a separate nomad_acl_binding_rule resource."
  value       = <<-EOT
resource "nomad_acl_binding_rule" "dex_management" {
  auth_method = "${var.auth_method_name}"
  description = "Grant Nomad management access to the local Dex admin user"
  selector    = "value.email == \"${var.oidc_admin_email}\""
  bind_type   = "management"
}
  EOT
}

output "nomad_login_command" {
  description = "Suggested CLI command to start an OIDC login flow after the auth method is created elsewhere."
  value       = "nomad login -method=${var.auth_method_name} -oidc-callback-addr=localhost:4649"
}
