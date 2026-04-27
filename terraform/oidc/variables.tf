variable "identity_client_index" {
  description = "Zero-based index of the Nomad client VM that should host the Dex container."
  type        = number
  default     = 0

  validation {
    condition     = var.identity_client_index >= 0
    error_message = "identity_client_index must be zero or greater."
  }
}

variable "dex_runtime" {
  description = "Where to run Dex: host runs Docker on macOS, vm runs Docker inside the selected Multipass client VM."
  type        = string
  default     = "host"

  validation {
    condition     = contains(["host", "vm"], var.dex_runtime)
    error_message = "dex_runtime must be either host or vm."
  }
}

variable "host_access_ip" {
  description = "Host IP that Multipass VMs can use to reach Docker running on macOS. Defaults to the first client subnet gateway, usually x.x.x.1."
  type        = string
  default     = ""
}

variable "dex_image" {
  description = "Container image used for the local OIDC provider."
  type        = string
  default     = "ghcr.io/dexidp/dex:v2.41.1"
}

variable "dex_container_name" {
  description = "Container name for the local Dex identity provider."
  type        = string
  default     = "nomad-local-dex"
}

variable "dex_http_port" {
  description = "Port exposed on the selected Nomad client VM for Dex HTTP traffic."
  type        = number
  default     = 5556
}

variable "auth_method_name" {
  description = "Suggested Nomad ACL auth method name for local OIDC logins."
  type        = string
  default     = "local-dex"
}

variable "auth_method_max_token_ttl" {
  description = "Suggested maximum TTL for Nomad tokens minted through the local OIDC flow."
  type        = string
  default     = "8h"
}

variable "make_default_auth_method" {
  description = "Suggested value for whether the separate Nomad auth method should be the default for `nomad login`."
  type        = bool
  default     = true
}

variable "oidc_admin_email" {
  description = "Email address for the local Dex admin user that can be matched by a separate Nomad binding rule."
  type        = string
  default     = "nomad-admin@example.com"
}

variable "oidc_admin_username" {
  description = "Username for the local Dex admin user."
  type        = string
  default     = "nomad-admin"
}

variable "additional_redirect_uris" {
  description = "Extra redirect URIs to allow on the Dex OIDC client."
  type        = list(string)
  default     = []
}
