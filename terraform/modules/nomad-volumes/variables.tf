variable "client_names" {
  description = "List of Nomad client VM names to configure host volumes on."
  type        = list(string)
}

variable "host_volumes" {
  description = "Map of host volumes to create. Key is the volume name."
  type = map(object({
    path        = string
    read_only   = optional(bool, false)
    permissions = optional(string, "755")
  }))
  default = {
    data = {
      path        = "/opt/nomad/volumes/data"
      read_only   = false
      permissions = "777"
    }
    secrets = {
      path        = "/opt/nomad/volumes/secrets"
      read_only   = false
      permissions = "700"
    }
    logs = {
      path        = "/opt/nomad/volumes/logs"
      read_only   = false
      permissions = "755"
    }
  }
}
