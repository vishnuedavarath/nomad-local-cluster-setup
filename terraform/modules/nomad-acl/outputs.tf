output "tokens" {
  description = "All ACL tokens (accessor_id and secret_id)."
  sensitive   = true
  value = {
    developer = {
      accessor_id = nomad_acl_token.developer.accessor_id
      secret_id   = nomad_acl_token.developer.secret_id
    }
    staging = {
      accessor_id = nomad_acl_token.staging.accessor_id
      secret_id   = nomad_acl_token.staging.secret_id
    }
    ops = {
      accessor_id = nomad_acl_token.ops.accessor_id
      secret_id   = nomad_acl_token.ops.secret_id
    }
    readonly = {
      accessor_id = nomad_acl_token.readonly.accessor_id
      secret_id   = nomad_acl_token.readonly.secret_id
    }
    admin = {
      accessor_id = nomad_acl_token.admin.accessor_id
      secret_id   = nomad_acl_token.admin.secret_id
    }
  }
}

output "admin_token" {
  description = "Admin management token secret_id."
  sensitive   = true
  value       = nomad_acl_token.admin.secret_id
}

output "ops_token" {
  description = "Ops token secret_id (full write access to all namespaces, nodes, volumes)."
  sensitive   = true
  value       = nomad_acl_token.ops.secret_id
}
