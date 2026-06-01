variable "client_names" {
  description = "List of Nomad client VM names (for installing device/driver plugins)."
  type        = list(string)
  default     = []
}

variable "csi_plugins" {
  description = "CSI plugins to deploy as Nomad jobs. Key is the plugin ID."
  type = map(object({
    docker_image    = string
    namespace       = optional(string, "default")
    datacenter      = optional(string, "dc1")
    type            = optional(string, "monolith") # "monolith", "controller", or "node"
    controller_args = optional(list(string), [])   # args for controller job (split mode)
    node_args       = optional(list(string), [])   # args for node job (split mode)
    args            = optional(list(string), [])   # args for monolith mode
    env             = optional(map(string), {})
    privileged      = optional(bool, true)
    mount_dirs      = optional(list(string), [])
    resources = optional(object({
      cpu    = optional(number, 100)
      memory = optional(number, 128)
    }), {})
  }))
  default = {}
}

variable "device_plugins" {
  description = "Device plugins to install on client VMs. Key is the plugin name."
  type = map(object({
    download_url = string
    binary_name  = optional(string, "") # defaults to key name
    plugin_dir   = optional(string, "/opt/nomad/plugins")
    config_hcl   = optional(string, "") # extra HCL config for the plugin
  }))
  default = {}
}

variable "driver_plugins" {
  description = "Task driver plugins to install on client VMs. Key is the plugin name."
  type = map(object({
    download_url = string
    binary_name  = optional(string, "") # defaults to key name
    plugin_dir   = optional(string, "/opt/nomad/plugins")
    config_hcl   = optional(string, "") # extra HCL config for the plugin
  }))
  default = {}
}
