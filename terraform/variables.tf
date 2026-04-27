variable "server_count" {
  description = "Number of Nomad server nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.server_count >= 1 && var.server_count % 2 == 1
    error_message = "server_count must be a positive odd number to preserve quorum semantics for the Nomad server cluster."
  }
}

variable "client_count" {
  description = "Number of Nomad client nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.client_count >= 1
    error_message = "client_count must be at least 1."
  }
}

variable "datacenter" {
  description = "Datacenter name for Nomad/Consul"
  type        = string
  default     = "dc1"

  validation {
    condition     = trimspace(var.datacenter) != ""
    error_message = "datacenter must not be empty."
  }
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

variable "vm_image" {
  description = <<-EOT
    Image to launch with Multipass. Multipass does not ship official Debian
    images in its image stream, so this defaults to the official Debian 12
    (bookworm) generic cloud image (arm64) hosted on cloud.debian.org.
    On Intel Macs / amd64 hosts, override to the amd64 image:
      https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
    You may also pass an Ubuntu LTS alias (e.g. "24.04", "noble", "jammy"),
    a local file:// path, or any URL to a cloud-init enabled qcow2 image.
    NOTE: Custom-URL images require the QEMU driver on macOS
    (`multipass set local.driver=qemu`).
  EOT
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"

  validation {
    condition     = trimspace(var.vm_image) != ""
    error_message = "vm_image must not be empty."
  }
}

variable "enable_acl" {
  description = "Enable Nomad ACL system"
  type        = bool
  default     = true
}

variable "nomad_edition" {
  description = "Nomad edition to install on all nodes. Use enterprise for Nomad Enterprise binaries."
  type        = string
  default     = "enterprise"

  validation {
    condition     = contains(["oss", "enterprise"], var.nomad_edition)
    error_message = "nomad_edition must be either oss or enterprise."
  }
}

variable "nomad_version" {
  description = "Base Nomad version to install. Enterprise builds automatically append +ent when nomad_edition is enterprise."
  type        = string
  default     = "1.11.3"

  validation {
    condition     = trimspace(var.nomad_version) != ""
    error_message = "nomad_version must not be empty."
  }
}

variable "nomad_enterprise_license" {
  description = "Nomad Enterprise license contents. Required when nomad_edition is enterprise."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.nomad_edition != "enterprise" || trimspace(var.nomad_enterprise_license) != "" || (trimspace(var.nomad_enterprise_license_file) != "" && fileexists(pathexpand(var.nomad_enterprise_license_file)))
    error_message = "Provide either nomad_enterprise_license or nomad_enterprise_license_file when nomad_edition is enterprise."
  }
}

variable "nomad_enterprise_license_file" {
  description = "Path on the local machine to a Nomad Enterprise .hclic file. Used when nomad_enterprise_license is not set."
  type        = string
  default     = "~/licenses/nomad-enterprise.hclic"

  validation {
    condition     = trimspace(var.nomad_enterprise_license_file) == "" || fileexists(pathexpand(var.nomad_enterprise_license_file))
    error_message = "nomad_enterprise_license_file must point to an existing local file."
  }
}

variable "nomad_enterprise_license_path" {
  description = "Absolute path on Nomad server VMs where the enterprise license file will be written."
  type        = string
  default     = "/etc/nomad.d/license.hclic"

  validation {
    condition     = startswith(var.nomad_enterprise_license_path, "/")
    error_message = "nomad_enterprise_license_path must be an absolute path."
  }
}
