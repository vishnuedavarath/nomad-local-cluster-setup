# Module: nomad-namespaces
# Creates Nomad namespaces. Decoupled from ACL and secrets.

terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

resource "nomad_namespace" "this" {
  for_each = var.namespaces

  name        = each.key
  description = each.value.description

  meta = each.value.meta
}
