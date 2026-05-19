# =============================================================================
# Variables - All configurable through terraform.tfvars
# =============================================================================

# --------------------------------------------------------------------------- #
# VM Infrastructure                                                            #
# --------------------------------------------------------------------------- #

variable "server_count" {
  description = "Number of Nomad server VMs."
  type        = number
  default     = 3
}

variable "client_count" {
  description = "Number of Nomad client VMs."
  type        = number
  default     = 3
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
  description = "Cloud image URL or Multipass alias for VMs."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
}

variable "server_cpus" {
  description = "CPUs per server VM."
  type        = number
  default     = 1
}

variable "server_memory" {
  description = "Memory per server VM."
  type        = string
  default     = "1G"
}

variable "server_disk" {
  description = "Disk per server VM."
  type        = string
  default     = "5G"
}

variable "client_cpus" {
  description = "CPUs per client VM."
  type        = number
  default     = 1
}

variable "client_memory" {
  description = "Memory per client VM."
  type        = string
  default     = "2G"
}

variable "client_disk" {
  description = "Disk per client VM."
  type        = string
  default     = "10G"
}

# --------------------------------------------------------------------------- #
# Cluster Configuration                                                        #
# --------------------------------------------------------------------------- #

variable "datacenter" {
  description = "Datacenter name for Nomad and Consul."
  type        = string
  default     = "dc1"
}

variable "nomad_edition" {
  description = "Nomad edition: 'oss' or 'enterprise'."
  type        = string
  default     = "oss"
}

variable "nomad_version" {
  description = "Nomad version to install."
  type        = string
  default     = "1.11.3"
}

variable "nomad_enterprise_license" {
  description = "Nomad Enterprise license content."
  type        = string
  sensitive   = true
  default     = ""
}

variable "nomad_enterprise_license_file" {
  description = "Path to local Nomad Enterprise license file."
  type        = string
  default     = ""
}

variable "nomad_license_path_on_vm" {
  description = "Path on VMs where the license file is stored."
  type        = string
  default     = "/etc/nomad.d/license.hclic"
}

variable "enable_acl" {
  description = "Enable Nomad ACL system."
  type        = bool
  default     = true
}

variable "enable_raw_exec" {
  description = "Enable raw_exec driver on clients."
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
  description = "Delay after VM launch before provisioning."
  type        = string
  default     = "30s"
}

variable "cluster_stabilize_delay" {
  description = "Delay after cluster config before proceeding."
  type        = string
  default     = "15s"
}

# --------------------------------------------------------------------------- #
# Feature Toggles                                                              #
# --------------------------------------------------------------------------- #

variable "enable_nomad_setup" {
  description = "Enable Nomad-dependent modules (set true after cluster is up)."
  type        = bool
  default     = false
}

variable "update_shell_env" {
  description = "Update ~/.zshrc with NOMAD_ADDR and NOMAD_TOKEN exports."
  type        = bool
  default     = true
}

variable "enable_host_volumes" {
  description = "Enable host volume setup on clients."
  type        = bool
  default     = true
}

variable "enable_jobs" {
  description = "Enable job deployments."
  type        = bool
  default     = true
}

variable "enable_autoscaler" {
  description = "Enable autoscaler deployment."
  type        = bool
  default     = false
}

variable "enable_oidc" {
  description = "Enable OIDC (Dex) provider."
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------- #
# ACL Configuration                                                            #
# --------------------------------------------------------------------------- #

variable "custom_acl_policies" {
  description = "Additional ACL policies to create."
  type = map(object({
    description = string
    rules_hcl   = string
  }))
  default = {}
}

# --------------------------------------------------------------------------- #
# Namespaces                                                                   #
# --------------------------------------------------------------------------- #

variable "namespaces" {
  description = "Nomad namespaces to create."
  type = map(object({
    description = string
    meta        = optional(map(string), {})
  }))
  default = {
    development = {
      description = "Development environment"
      meta        = { environment = "dev", owner = "dev-team" }
    }
    staging = {
      description = "Staging environment"
      meta        = { environment = "staging", owner = "qa-team" }
    }
    production = {
      description = "Production environment"
      meta        = { environment = "prod", owner = "ops-team" }
    }
  }
}

# --------------------------------------------------------------------------- #
# Host Volumes                                                                 #
# --------------------------------------------------------------------------- #

variable "host_volumes" {
  description = "Host volumes to configure on client VMs."
  type = map(object({
    path        = string
    read_only   = optional(bool, false)
    permissions = optional(string, "755")
  }))
  default = {
    data = {
      path        = "/opt/nomad/volumes/data"
      permissions = "777"
    }
    secrets = {
      path        = "/opt/nomad/volumes/secrets"
      permissions = "700"
    }
    logs = {
      path        = "/opt/nomad/volumes/logs"
      permissions = "755"
    }
  }
}

# --------------------------------------------------------------------------- #
# Secrets (Nomad Variables)                                                    #
# --------------------------------------------------------------------------- #

variable "nomad_secrets" {
  description = "Nomad Variables (secrets) to create."
  type = map(object({
    path      = string
    namespace = string
    items     = map(string)
  }))
  sensitive = true
  default   = {}
}

# --------------------------------------------------------------------------- #
# Jobs                                                                         #
# --------------------------------------------------------------------------- #

variable "jobs" {
  description = "Plain jobspec files to deploy. Key = name, value = file path."
  type        = map(string)
  default     = {}
}

variable "templated_jobs" {
  description = "Templated jobspec files to deploy."
  type = map(object({
    template_path = string
    vars          = map(string)
  }))
  default = {}
}

# --------------------------------------------------------------------------- #
# Autoscaler                                                                   #
# --------------------------------------------------------------------------- #

variable "autoscaler_namespace" {
  description = "Namespace for the autoscaler job."
  type        = string
  default     = "default"
}

variable "autoscaler_version" {
  description = "Autoscaler version (empty = latest)."
  type        = string
  default     = ""
}

variable "autoscaler_use_local_binary" {
  description = "Use a locally built autoscaler binary."
  type        = bool
  default     = false
}

variable "autoscaler_local_binary_path" {
  description = "Path to local autoscaler binary."
  type        = string
  default     = "~/projects/hashicorp/nomad-autoscaler/bin/nomad-autoscaler"
}

variable "autoscaler_job_template_path" {
  description = "Path to the autoscaler job template."
  type        = string
  default     = "../../../jobs/autoscaler.nomad.hcl.tftpl"
}

# --------------------------------------------------------------------------- #
# OIDC (Dex)                                                                   #
# --------------------------------------------------------------------------- #

variable "oidc_identity_client_index" {
  description = "Index of client VM to host Dex."
  type        = number
  default     = 0
}

variable "oidc_dex_runtime" {
  description = "Where to run Dex: 'host' or 'vm'."
  type        = string
  default     = "host"
}

variable "oidc_host_access_ip" {
  description = "Host IP reachable from VMs for Dex."
  type        = string
  default     = ""
}

variable "oidc_dex_image" {
  description = "Dex container image."
  type        = string
  default     = "ghcr.io/dexidp/dex:v2.41.1"
}

variable "oidc_dex_container_name" {
  description = "Dex container name."
  type        = string
  default     = "nomad-local-dex"
}

variable "oidc_dex_http_port" {
  description = "Dex HTTP port."
  type        = number
  default     = 5556
}

variable "oidc_dex_client_id" {
  description = "OIDC client ID for Nomad."
  type        = string
  default     = "nomad-local"
}

variable "oidc_admin_email" {
  description = "Dex admin email."
  type        = string
  default     = "nomad-admin@example.com"
}

variable "oidc_admin_username" {
  description = "Dex admin username."
  type        = string
  default     = "nomad-admin"
}

variable "oidc_admin_password_hash" {
  description = "Bcrypt hash of the Dex admin password."
  type        = string
  default     = "$2y$10$uaHf2Q.dj9C/5y4Olmk/DOEqeuRUibBMk0u50nsKrZ1Ga.3D0HNfS"
}

variable "oidc_additional_redirect_uris" {
  description = "Additional OIDC redirect URIs."
  type        = list(string)
  default     = []
}

variable "oidc_create_auth_method" {
  description = "Create the Nomad ACL auth method and binding rules for OIDC."
  type        = bool
  default     = true
}

variable "oidc_auth_method_name" {
  description = "Name of the Nomad ACL OIDC auth method."
  type        = string
  default     = "local-dex"
}

variable "oidc_auth_method_max_token_ttl" {
  description = "Maximum TTL for tokens minted through OIDC login."
  type        = string
  default     = "8h"
}

variable "oidc_make_default_auth_method" {
  description = "Make the OIDC auth method the default for 'nomad login'."
  type        = bool
  default     = true
}

variable "oidc_binding_rules" {
  description = "Additional ACL binding rules for the OIDC auth method."
  type = map(object({
    description = string
    selector    = string
    bind_type   = string
    bind_name   = string
  }))
  default = {}
}
