# Nomad Namespace Configuration

resource "nomad_namespace" "development" {
  name        = "development"
  description = "Development environment for testing and experimentation"

  meta = {
    environment = "dev"
    owner       = "dev-team"
  }
}

resource "nomad_namespace" "staging" {
  name        = "staging"
  description = "Staging environment for pre-production testing"

  meta = {
    environment = "staging"
    owner       = "qa-team"
  }
}

resource "nomad_namespace" "production" {
  name        = "production"
  description = "Production environment for live workloads"

  meta = {
    environment = "prod"
    owner       = "ops-team"
  }
}

output "namespaces" {
  description = "Created namespaces"
  value = {
    development = nomad_namespace.development.name
    staging     = nomad_namespace.staging.name
    production  = nomad_namespace.production.name
  }
}
