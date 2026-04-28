output "service_name" {
  description = "Consul service name registered for the webapp."
  value       = var.service_name
}

output "consul_dns_lookup" {
  description = "Consul DNS name to query for healthy webapp endpoints."
  value       = "${var.service_name}.service.consul"
}

output "consul_api_lookup" {
  description = "Consul HTTP API path that returns healthy webapp instances."
  value       = "/v1/health/service/${var.service_name}?passing=true"
}

output "fabio_ui_hint" {
  description = "If Fabio is deployed, browse this on any client to see routes."
  value       = var.deploy_fabio_lb ? "http://<any-client-ip>:9998" : "fabio not deployed (set deploy_fabio_lb=true to enable)"
}

output "webapp_job_id" {
  description = "Nomad job ID for the webapp."
  value       = nomad_job.webapp.id
}
