variable "nomad_token" {
  description = "Nomad ACL token (management). Falls back to the cluster bootstrap token when empty."
  type        = string
  sensitive   = true
  default     = ""
}

variable "namespace" {
  description = "Nomad namespace to deploy the autoscaler into."
  type        = string
  default     = "default"
}

variable "datacenter" {
  description = "Nomad datacenter the job should run in."
  type        = string
  default     = "dc1"
}

variable "autoscaler_version" {
  description = <<-EOT
    Released nomad-autoscaler version to deploy (e.g. "0.4.7"). Leave empty to
    automatically resolve the latest release from GitHub. Ignored when
    `use_local_binary = true`.
  EOT
  type        = string
  default     = ""
}

variable "use_local_binary" {
  description = <<-EOT
    When true, upload a locally built nomad-autoscaler binary from
    `var.local_binary_path` to every Nomad client and run that instead of
    downloading a release artifact.
  EOT
  type        = bool
  default     = false
}

variable "local_binary_path" {
  description = "Path to a locally built nomad-autoscaler binary on the operator host."
  type        = string
  default     = "~/projects/hashicorp/nomad-autoscaler/bin/nomad-autoscaler"
}
