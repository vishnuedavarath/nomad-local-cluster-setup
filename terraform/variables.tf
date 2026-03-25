variable "server_count" {
  description = "Number of Nomad server nodes"
  type        = number
  default     = 3
}

variable "client_count" {
  description = "Number of Nomad client nodes"
  type        = number
  default     = 3
}

variable "datacenter" {
  description = "Datacenter name for Nomad/Consul"
  type        = string
  default     = "dc1"
}

variable "server_cpus" {
  description = "CPUs for server VMs"
  type        = number
  default     = 1
}

variable "server_memory" {
  description = "Memory for server VMs (e.g., '1G')"
  type        = string
  default     = "1G"
}

variable "server_disk" {
  description = "Disk size for server VMs (e.g., '5G')"
  type        = string
  default     = "5G"
}

variable "client_cpus" {
  description = "CPUs for client VMs"
  type        = number
  default     = 1
}

variable "client_memory" {
  description = "Memory for client VMs (e.g., '2G')"
  type        = string
  default     = "2G"
}

variable "client_disk" {
  description = "Disk size for client VMs (e.g., '10G')"
  type        = string
  default     = "10G"
}

variable "enable_acl" {
  description = "Enable Nomad ACL system"
  type        = bool
  default     = true
}
