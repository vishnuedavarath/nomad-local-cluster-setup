variable "nomad_address" {
  description = "Nomad cluster HTTP address."
  type        = string
}

variable "client_names" {
  description = "List of Nomad client VM names."
  type        = list(string)
}

variable "client_ips" {
  description = "List of Nomad client VM IPs."
  type        = list(string)
}

variable "identity_client_index" {
  description = "Index of the client VM to host Dex."
  type        = number
  default     = 0
}

variable "dex_runtime" {
  description = "Where to run Dex: 'host' (Docker on macOS) or 'vm' (Docker inside Multipass)."
  type        = string
  default     = "host"

  validation {
    condition     = contains(["host", "vm"], var.dex_runtime)
    error_message = "Must be 'host' or 'vm'."
  }
}

variable "host_access_ip" {
  description = "Host IP reachable from VMs (defaults to subnet gateway x.x.x.1)."
  type        = string
  default     = ""
}

variable "dex_image" {
  description = "Dex container image."
  type        = string
  default     = "ghcr.io/dexidp/dex:v2.41.1"
}

variable "dex_container_name" {
  description = "Docker container name for Dex."
  type        = string
  default     = "nomad-local-dex"
}

variable "dex_http_port" {
  description = "Port for Dex HTTP traffic."
  type        = number
  default     = 5556
}

variable "dex_client_id" {
  description = "OIDC client ID."
  type        = string
  default     = "nomad-local"
}

variable "oidc_admin_email" {
  description = "Admin user email for Dex."
  type        = string
  default     = "nomad-admin@example.com"
}

variable "oidc_admin_username" {
  description = "Admin username for Dex."
  type        = string
  default     = "nomad-admin"
}

variable "oidc_admin_password_hash" {
  description = "Bcrypt hash of the admin password."
  type        = string
  default     = "$2y$10$uaHf2Q.dj9C/5y4Olmk/DOEqeuRUibBMk0u50nsKrZ1Ga.3D0HNfS"
}

variable "additional_redirect_uris" {
  description = "Extra OIDC redirect URIs."
  type        = list(string)
  default     = []
}

variable "create_auth_method" {
  description = "Create the Nomad ACL auth method and binding rules."
  type        = bool
  default     = true
}

variable "auth_method_name" {
  description = "Name of the Nomad ACL auth method."
  type        = string
  default     = "local-dex"
}

variable "auth_method_max_token_ttl" {
  description = "Maximum TTL for tokens minted through OIDC."
  type        = string
  default     = "8h"
}

variable "make_default_auth_method" {
  description = "Make this auth method the default for 'nomad login'."
  type        = bool
  default     = true
}

variable "binding_rules" {
  description = "Additional ACL binding rules for the OIDC auth method."
  type = map(object({
    description = string
    selector    = string
    bind_type   = string
    bind_name   = string
  }))
  default = {}
}
