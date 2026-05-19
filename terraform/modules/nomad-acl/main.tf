# Module: nomad-acl
# Manages ACL policies and tokens.
# Decoupled from cluster setup - requires a running Nomad with ACLs enabled.

terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

# --------------------------------------------------------------------------- #
# ACL Policies                                                                 #
# --------------------------------------------------------------------------- #

resource "nomad_acl_policy" "developer" {
  name        = "developer"
  description = "Full access to development namespace"

  rules_hcl = <<-EOT
    namespace "development" {
      policy       = "write"
      capabilities = ["submit-job", "read-job", "list-jobs", "read-logs", "alloc-exec", "alloc-lifecycle", "csi-read-volume", "csi-write-volume"]
    }
    namespace "staging" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job", "read-logs"]
    }
    namespace "production" {
      policy = "deny"
    }
    namespace "default" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job"]
    }
    node  { policy = "read" }
    agent { policy = "read" }
  EOT
}

resource "nomad_acl_policy" "staging" {
  name        = "staging"
  description = "Full access to staging namespace"

  rules_hcl = <<-EOT
    namespace "development" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job", "read-logs"]
    }
    namespace "staging" {
      policy       = "write"
      capabilities = ["submit-job", "read-job", "list-jobs", "read-logs", "alloc-exec", "alloc-lifecycle", "csi-read-volume", "csi-write-volume"]
    }
    namespace "production" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job", "read-logs"]
    }
    namespace "default" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job"]
    }
    node  { policy = "read" }
    agent { policy = "read" }
  EOT
}

resource "nomad_acl_policy" "ops" {
  name        = "ops"
  description = "Full access to all namespaces for operations team"

  rules_hcl = <<-EOT
    namespace "*" {
      policy       = "write"
      capabilities = ["submit-job", "read-job", "list-jobs", "read-logs", "alloc-exec", "alloc-lifecycle", "csi-read-volume", "csi-write-volume", "alloc-node-exec"]
    }
    node     { policy = "write" }
    agent    { policy = "write" }
    operator { policy = "write" }
    quota    { policy = "write" }
    host_volume "*" { policy = "write" }
    plugin   { policy = "read" }
  EOT
}

resource "nomad_acl_policy" "readonly" {
  name        = "readonly"
  description = "Read-only access to all namespaces"

  rules_hcl = <<-EOT
    namespace "*" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job", "read-logs"]
    }
    node  { policy = "read" }
    agent { policy = "read" }
  EOT
}

# --------------------------------------------------------------------------- #
# Dynamic policies from variable                                               #
# --------------------------------------------------------------------------- #

resource "nomad_acl_policy" "custom" {
  for_each = var.custom_policies

  name        = each.key
  description = each.value.description
  rules_hcl   = each.value.rules_hcl
}

# --------------------------------------------------------------------------- #
# ACL Tokens                                                                   #
# --------------------------------------------------------------------------- #

resource "nomad_acl_token" "developer" {
  name     = "developer-token"
  type     = "client"
  policies = [nomad_acl_policy.developer.name]
}

resource "nomad_acl_token" "staging" {
  name     = "staging-token"
  type     = "client"
  policies = [nomad_acl_policy.staging.name]
}

resource "nomad_acl_token" "ops" {
  name     = "ops-token"
  type     = "client"
  policies = [nomad_acl_policy.ops.name]
}

resource "nomad_acl_token" "readonly" {
  name     = "readonly-token"
  type     = "client"
  policies = [nomad_acl_policy.readonly.name]
}

resource "nomad_acl_token" "admin" {
  name   = "admin-token"
  type   = "management"
  global = true
}
