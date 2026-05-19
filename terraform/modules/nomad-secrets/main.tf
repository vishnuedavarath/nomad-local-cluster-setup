# Module: nomad-secrets
# Manages Nomad Variables (built-in secret storage).

terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

resource "nomad_variable" "this" {
  for_each = var.secrets

  path      = each.value.path
  namespace = each.value.namespace
  items     = each.value.items
}
