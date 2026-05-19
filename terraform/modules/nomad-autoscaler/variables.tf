variable "nomad_address" {
  description = "Nomad cluster HTTP address."
  type        = string
}

variable "nomad_token" {
  description = "Nomad ACL token for the autoscaler."
  type        = string
  sensitive   = true
  default     = ""
}

variable "client_names" {
  description = "Nomad client VM names (for local binary upload)."
  type        = list(string)
  default     = []
}

variable "namespace" {
  description = "Nomad namespace for the autoscaler job."
  type        = string
  default     = "default"
}

variable "datacenter" {
  description = "Nomad datacenter."
  type        = string
  default     = "dc1"
}

variable "autoscaler_version" {
  description = "Released version to deploy (empty = resolve latest from GitHub)."
  type        = string
  default     = ""
}

variable "use_local_binary" {
  description = "Upload and use a locally built binary instead of a release."
  type        = bool
  default     = false
}

variable "local_binary_path" {
  description = "Path to locally built nomad-autoscaler binary."
  type        = string
  default     = "~/projects/hashicorp/nomad-autoscaler/bin/nomad-autoscaler"
}

variable "job_template_path" {
  description = "Path to the autoscaler job template file."
  type        = string
}
