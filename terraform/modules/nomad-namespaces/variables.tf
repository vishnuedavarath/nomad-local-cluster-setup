variable "namespaces" {
  description = "Map of namespaces to create. Key is the namespace name."
  type = map(object({
    description = string
    meta        = optional(map(string), {})
  }))
  default = {
    development = {
      description = "Development environment for testing and experimentation"
      meta        = { environment = "dev", owner = "dev-team" }
    }
    staging = {
      description = "Staging environment for pre-production testing"
      meta        = { environment = "staging", owner = "qa-team" }
    }
    production = {
      description = "Production environment for live workloads"
      meta        = { environment = "prod", owner = "ops-team" }
    }
  }
}
