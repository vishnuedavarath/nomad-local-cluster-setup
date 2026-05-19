variable "server_names" {
  description = "List of server VM names (from multipass-instances module)."
  type        = list(string)
}

variable "client_names" {
  description = "List of client VM names (from multipass-instances module)."
  type        = list(string)
}

variable "server_ips" {
  description = "List of server VM IP addresses (for retry_join)."
  type        = list(string)
}

variable "datacenter" {
  description = "Datacenter name for Nomad and Consul."
  type        = string
  default     = "dc1"
}

variable "nomad_edition" {
  description = "Nomad edition: 'oss' or 'enterprise'."
  type        = string
  default     = "oss"

  validation {
    condition     = contains(["oss", "enterprise"], var.nomad_edition)
    error_message = "nomad_edition must be 'oss' or 'enterprise'."
  }
}

variable "nomad_version" {
  description = "Nomad version to install (e.g., '1.11.3')."
  type        = string
  default     = "1.11.3"
}

variable "nomad_enterprise_license" {
  description = "Nomad Enterprise license content (raw string)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "nomad_enterprise_license_file" {
  description = "Path to a local Nomad Enterprise .hclic license file."
  type        = string
  default     = ""
}

variable "nomad_license_path_on_vm" {
  description = "Path on the VM where the enterprise license will be stored."
  type        = string
  default     = "/etc/nomad.d/license.hclic"
}

variable "enable_acl" {
  description = "Enable Nomad ACL system."
  type        = bool
  default     = true
}

variable "enable_raw_exec" {
  description = "Enable the raw_exec task driver on clients."
  type        = bool
  default     = true
}

variable "enable_docker_volumes" {
  description = "Enable Docker volume mounts on clients."
  type        = bool
  default     = true
}

variable "install_docker" {
  description = "Install Docker on client VMs."
  type        = bool
  default     = true
}

variable "vm_ready_delay" {
  description = "Time to wait for VMs to be ready after launch."
  type        = string
  default     = "30s"
}

variable "cluster_stabilize_delay" {
  description = "Time to wait for the Nomad cluster to stabilize after configuration."
  type        = string
  default     = "15s"
}
