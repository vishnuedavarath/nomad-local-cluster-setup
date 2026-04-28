output "autoscaler_version" {
  description = "Version of nomad-autoscaler that was deployed (or 'local' for a locally built binary)."
  value       = local.resolved_version
}

output "autoscaler_mode" {
  description = "Source of the autoscaler binary."
  value       = var.use_local_binary ? "local-binary" : "released-artifact"
}

output "job_id" {
  description = "Nomad job ID for the deployed autoscaler."
  value       = nomad_job.autoscaler.id
}
