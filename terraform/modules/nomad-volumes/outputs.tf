output "configured_volumes" {
  description = "Map of configured host volume names and paths."
  value       = { for k, v in var.host_volumes : k => v.path }
}
