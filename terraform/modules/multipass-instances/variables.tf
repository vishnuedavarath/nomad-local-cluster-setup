variable "server_count" {
  description = "Number of Nomad server VMs to launch."
  type        = number
  default     = 3

  validation {
    condition     = var.server_count >= 1 && var.server_count % 2 == 1
    error_message = "server_count must be a positive odd number for quorum."
  }
}

variable "client_count" {
  description = "Number of Nomad client VMs to launch."
  type        = number
  default     = 3

  validation {
    condition     = var.client_count >= 1
    error_message = "client_count must be at least 1."
  }
}

variable "server_name_prefix" {
  description = "Prefix for server VM names."
  type        = string
  default     = "nomad-server"
}

variable "client_name_prefix" {
  description = "Prefix for client VM names."
  type        = string
  default     = "nomad-client"
}

variable "vm_image" {
  description = "Cloud image URL or alias for Multipass VMs."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"

  validation {
    condition     = trimspace(var.vm_image) != ""
    error_message = "vm_image must not be empty."
  }
}

variable "server_cpus" {
  description = "Number of CPUs for each server VM."
  type        = number
  default     = 1
}

variable "server_memory" {
  description = "Memory allocation for each server VM (e.g., '1G')."
  type        = string
  default     = "1G"
}

variable "server_disk" {
  description = "Disk size for each server VM (e.g., '5G')."
  type        = string
  default     = "5G"
}

variable "client_cpus" {
  description = "Number of CPUs for each client VM."
  type        = number
  default     = 1
}

variable "client_memory" {
  description = "Memory allocation for each client VM (e.g., '2G')."
  type        = string
  default     = "2G"
}

variable "client_disk" {
  description = "Disk size for each client VM (e.g., '10G')."
  type        = string
  default     = "10G"
}
