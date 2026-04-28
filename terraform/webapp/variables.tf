variable "namespace" {
  description = "Nomad namespace to deploy the webapp into."
  type        = string
  default     = "default"
}

variable "datacenter" {
  description = "Nomad datacenter the job should run in."
  type        = string
  default     = "dc1"
}

variable "service_name" {
  description = "Consul service name registered for the webapp."
  type        = string
  default     = "webapp"
}

variable "image" {
  description = "Container image for the webapp."
  type        = string
  default     = "nginx:latest"
}

variable "replicas" {
  description = "Number of webapp allocations to run."
  type        = number
  default     = 3
}

variable "enable_scaling" {
  description = "Attach a `scaling` stanza so the nomad-autoscaler can manage the allocation count."
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Minimum allocation count when autoscaling is enabled."
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum allocation count when autoscaling is enabled."
  type        = number
  default     = 6
}

variable "target_cpu_pct" {
  description = "Target average CPU usage (percentage) the autoscaler should aim for."
  type        = number
  default     = 70
}

variable "deploy_fabio_lb" {
  description = <<-EOT
    Optional: also deploy a small Fabio load balancer job that fronts every
    Consul service tagged `urlprefix-/`. Defaults to false because the
    primary routing mechanism is Consul service discovery (DNS / API).
  EOT
  type        = bool
  default     = false
}
