output "nginx_job_id" {
  description = "The ID of the deployed nginx job"
  value       = nomad_job.nginx.id
}

output "nginx_job_status" {
  description = "The status of the deployed nginx job"
  value       = nomad_job.nginx.status
}

output "nomad_address_used" {
  description = "The Nomad address used from cluster state"
  value       = local.nomad_address
}
