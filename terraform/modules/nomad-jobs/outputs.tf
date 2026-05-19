output "plain_job_ids" {
  description = "IDs of deployed plain jobs."
  value       = { for k, j in nomad_job.plain : k => j.id }
}

output "templated_job_ids" {
  description = "IDs of deployed templated jobs."
  value       = { for k, j in nomad_job.templated : k => j.id }
}
