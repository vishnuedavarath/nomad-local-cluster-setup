# Job ACL - Grant workloads access to secrets via Workload Identity
# The job_acl block in nomad_acl_policy binds policies to job workload identities

# Policy allowing jobs in development namespace to read secrets
resource "nomad_acl_policy" "workload_dev_secrets" {
  name        = "workload-dev-secrets"
  description = "Allow development workloads to read their secrets"

  # Rules for what the policy grants
  rules_hcl = <<-EOT
    # Access to variables (secrets)
    namespace "development" {
      variables {
        # Allow read access to secrets/* path
        path "secrets/*" {
          capabilities = ["read"]
        }
        
        # Allow read access to job-specific variables
        path "nomad/jobs/*" {
          capabilities = ["read"]
        }
      }
    }
  EOT

  # job_acl binds this policy to workload identities
  # Jobs matching this criteria automatically get this policy
  job_acl {
    namespace = "development"
    # Empty job_id = applies to ALL jobs in the namespace
    # If you want specific jobs, use: job_id = "myapp"
  }

}

# Policy for specific job pattern - only api-* jobs can access API secrets
resource "nomad_acl_policy" "workload_api_secrets" {
  name        = "workload-api-secrets"
  description = "Allow api-* jobs to read API secrets"

  rules_hcl = <<-EOT
    namespace "development" {
      variables {
        path "secrets/api" {
          capabilities = ["read"]
        }
      }
    }
  EOT

  job_acl {
    namespace = "development"
    job_id    = "api-*" # Wildcard - matches api-users, api-orders, etc.
  }
}

# Policy for staging workloads
resource "nomad_acl_policy" "workload_staging_secrets" {
  name        = "workload-staging-secrets"
  description = "Allow staging workloads to read staging secrets"

  rules_hcl = <<-EOT
    namespace "staging" {
      variables {
        path "secrets/*" {
          capabilities = ["read"]
        }
      }
    }
  EOT

  job_acl {
    namespace = "staging"
  }
}

# Policy for production workloads - more restrictive
resource "nomad_acl_policy" "workload_prod_secrets" {
  name        = "workload-prod-secrets"
  description = "Allow production workloads to read their app secrets only"

  rules_hcl = <<-EOT
    namespace "production" {
      variables {
        # Only allow app secrets, not TLS (handled separately)
        path "secrets/app" {
          capabilities = ["read"]
        }
      }
    }
  EOT

  job_acl {
    namespace = "production"
  }
}

# Example job that uses secrets via workload identity
resource "nomad_job" "secret_demo" {
  jobspec = <<-EOT
    job "secret-demo" {
      datacenters = ["local-dc"]
      namespace   = "development"
      type        = "service"

      group "app" {
        count = 1

        task "reader" {
          driver = "docker"

          config {
            image   = "alpine:latest"
            command = "/bin/sh"
            args    = ["-c", "cat /secrets/db.env && sleep 3600"]
          }

          # Template that reads from Nomad Variables using workload identity
          template {
            data = <<EOF
{{ with nomadVar "secrets/database" }}
DB_USER={{ .username }}
DB_PASS={{ .password }}
DB_HOST={{ .host }}
DB_PORT={{ .port }}
DB_NAME={{ .database }}
{{ end }}
EOF
            destination = "secrets/db.env"
            env         = true  # Also export as environment variables
          }

          # Read API keys too
          template {
            data = <<EOF
{{ with nomadVar "secrets/api" }}
STRIPE_KEY={{ .stripe_key }}
SENDGRID_KEY={{ .sendgrid_key }}
{{ end }}
EOF
            destination = "secrets/api.env"
            env         = true
          }

          resources {
            cpu    = 50
            memory = 32
          }
        }
      }
    }
  EOT
}

# Output
output "job_acl_policies" {
  description = "Job ACL policies that grant workload access to secrets"
  value = {
    development = {
      policy     = nomad_acl_policy.workload_dev_secrets.name
      applies_to = "All jobs in development namespace"
      secrets    = "secrets/*"
    }
    api_specific = {
      policy     = nomad_acl_policy.workload_api_secrets.name
      applies_to = "Jobs matching 'api-*' in development"
      secrets    = "secrets/api"
    }
    staging = {
      policy     = nomad_acl_policy.workload_staging_secrets.name
      applies_to = "All jobs in staging namespace"
      secrets    = "secrets/*"
    }
    production = {
      policy     = nomad_acl_policy.workload_prod_secrets.name
      applies_to = "All jobs in production namespace"
      secrets    = "secrets/app (not TLS)"
    }
  }
}

output "test_command" {
  value = "After apply, check logs: nomad alloc logs -namespace=development <alloc-id-of-secret-demo>"
}
