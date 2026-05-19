output "version" {
  description = "Deployed autoscaler version."
  value       = local.resolved_version
}

output "mode" {
  description = "Autoscaler binary source."
  value       = var.use_local_binary ? "local-binary" : "released-artifact"
}

output "job_id" {
  description = "Nomad job ID."
  value       = nomad_job.autoscaler.id
}
