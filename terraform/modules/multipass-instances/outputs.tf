output "server_names" {
  description = "Names of the server VMs."
  value       = local.server_names
}

output "client_names" {
  description = "Names of the client VMs."
  value       = local.client_names
}

output "server_ips" {
  description = "IPv4 addresses of server VMs."
  value       = [for s in multipass_instance.servers : s.ipv4]
}

output "client_ips" {
  description = "IPv4 addresses of client VMs."
  value       = [for c in multipass_instance.clients : c.ipv4]
}
