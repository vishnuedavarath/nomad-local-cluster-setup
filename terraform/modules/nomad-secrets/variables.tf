variable "secrets" {
  description = "Map of Nomad Variables (secrets) to create. Key is a logical name."
  type = map(object({
    path      = string
    namespace = string
    items     = map(string)
  }))
  default = {}
}
