output "secret_paths" {
  description = "Map of secret logical names to their Nomad Variable paths."
  value       = { for k, v in nomad_variable.this : k => v.path }
}
