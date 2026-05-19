output "namespace_names" {
  description = "List of created namespace names."
  value       = [for ns in nomad_namespace.this : ns.name]
}

output "namespaces" {
  description = "Map of created namespaces."
  value       = { for k, ns in nomad_namespace.this : k => ns.name }
}
