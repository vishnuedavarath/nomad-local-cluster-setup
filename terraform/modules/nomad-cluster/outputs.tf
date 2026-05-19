locals {
  acl_bootstrap_file = "${path.module}/.nomad_acl_bootstrap.json"
  acl_bootstrap_json = var.enable_acl ? (
    length(data.local_file.acl_bootstrap) > 0 ? data.local_file.acl_bootstrap[0].content : "{}"
  ) : "{}"
  acl_bootstrap_token = var.enable_acl ? try(
    jsondecode(local.acl_bootstrap_json).SecretID,
    "bootstrap-pending"
  ) : ""
}

output "nomad_address" {
  description = "Nomad cluster HTTP address."
  value       = "http://${var.server_ips[0]}:4646"
}

output "consul_address" {
  description = "Consul cluster HTTP address."
  value       = "http://${var.server_ips[0]}:8500"
}

output "acl_bootstrap_token" {
  description = "Nomad ACL management bootstrap token. Will be 'bootstrap-pending' until a refresh/second apply after initial bootstrap."
  value       = local.acl_bootstrap_token
  sensitive   = true
}

output "acl_bootstrapped" {
  description = "Whether ACL bootstrap has completed successfully."
  value       = local.acl_bootstrap_token != "" && local.acl_bootstrap_token != "bootstrap-pending"
}

output "nomad_release_version" {
  description = "Resolved Nomad release version string."
  value       = local.nomad_release_version
}

output "cluster_ready" {
  description = "Marker that the cluster is ready (depends on stabilization wait)."
  value       = time_sleep.wait_for_cluster.id
}
