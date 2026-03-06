# Nomad Namespaces and ACL Configuration

# Create namespaces
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

# ACL Policies

# Developer policy - full access to development namespace
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

    node {
      policy = "read"
    }

    agent {
      policy = "read"
    }
  EOT
}

# QA/Staging policy - full access to staging, read to dev
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

    node {
      policy = "read"
    }

    agent {
      policy = "read"
    }
  EOT
}

# Ops/Production policy - full access to all namespaces
resource "nomad_acl_policy" "ops" {
  name        = "ops"
  description = "Full access to all namespaces for operations team"

  rules_hcl = <<-EOT
    namespace "*" {
      policy       = "write"
      capabilities = ["submit-job", "read-job", "list-jobs", "read-logs", "alloc-exec", "alloc-lifecycle", "csi-read-volume", "csi-write-volume", "alloc-node-exec"]
    }

    node {
      policy = "write"
    }

    agent {
      policy = "write"
    }

    operator {
      policy = "write"
    }

    quota {
      policy = "write"
    }

    host_volume "*" {
      policy = "write"
    }

    plugin {
      policy = "read"
    }
  EOT
}

# Read-only policy for monitoring/observability
resource "nomad_acl_policy" "readonly" {
  name        = "readonly"
  description = "Read-only access to all namespaces for monitoring"

  rules_hcl = <<-EOT
    namespace "*" {
      policy       = "read"
      capabilities = ["list-jobs", "read-job", "read-logs"]
    }

    node {
      policy = "read"
    }

    agent {
      policy = "read"
    }
  EOT
}

# Create ACL tokens for each role
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

# Admin token with full management access
resource "nomad_acl_token" "admin" {
  name   = "admin-token"
  type   = "management"
  global = true
}

# Outputs
output "namespaces" {
  description = "Created namespaces"
  value = {
    development = nomad_namespace.development.name
    staging     = nomad_namespace.staging.name
    production  = nomad_namespace.production.name
  }
}

output "acl_tokens" {
  description = "ACL tokens (use these to authenticate)"
  sensitive   = true
  value = {
    developer = {
      accessor_id = nomad_acl_token.developer.accessor_id
      secret_id   = nomad_acl_token.developer.secret_id
    }
    staging = {
      accessor_id = nomad_acl_token.staging.accessor_id
      secret_id   = nomad_acl_token.staging.secret_id
    }
    ops = {
      accessor_id = nomad_acl_token.ops.accessor_id
      secret_id   = nomad_acl_token.ops.secret_id
    }
    readonly = {
      accessor_id = nomad_acl_token.readonly.accessor_id
      secret_id   = nomad_acl_token.readonly.secret_id
    }
    admin = {
      accessor_id = nomad_acl_token.admin.accessor_id
      secret_id   = nomad_acl_token.admin.secret_id
    }
  }
}

output "token_usage" {
  description = "How to use tokens"
  value       = "Export: NOMAD_TOKEN=$(terraform output -json acl_tokens | jq -r '.developer.secret_id')"
}
