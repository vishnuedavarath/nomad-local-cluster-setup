output "csi_plugin_ids" {
  description = "Map of CSI plugin name to plugin ID."
  value       = { for k, v in var.csi_plugins : k => k }
}

output "device_plugins_installed" {
  description = "List of device plugins installed on clients."
  value       = keys(var.device_plugins)
}

output "driver_plugins_installed" {
  description = "List of driver plugins installed on clients."
  value       = keys(var.driver_plugins)
}
