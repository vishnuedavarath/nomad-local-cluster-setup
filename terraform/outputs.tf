output "nomad_ui_url" {
  description = "URL for the Nomad UI"
  value       = "http://${multipass_instance.nomad_servers[0].ipv4}:4646"
}

output "consul_ui_url" {
  description = "URL for the Consul UI"
  value       = "http://${multipass_instance.nomad_servers[0].ipv4}:8500"
}

output "nomad_addr_export" {
  description = "Export command for NOMAD_ADDR environment variable"
  value       = "export NOMAD_ADDR=http://${multipass_instance.nomad_servers[0].ipv4}:4646"
}

output "server_ips" {
  description = "IP addresses of all Nomad server nodes"
  value       = [for s in multipass_instance.nomad_servers : s.ipv4]
}

output "client_ips" {
  description = "IP addresses of all Nomad client nodes"
  value       = [for c in multipass_instance.nomad_clients : c.ipv4]
}

output "server_names" {
  description = "Names of all Nomad server VMs"
  value       = local.server_names
}

output "client_names" {
  description = "Names of all Nomad client VMs"
  value       = local.client_names
}
