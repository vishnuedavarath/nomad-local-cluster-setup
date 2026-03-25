# Nomad Secrets Management
# Using Nomad Variables (built-in secret storage with ACL support)

resource "nomad_variable" "db_credentials" {
  path      = "secrets/database"
  namespace = nomad_namespace.development.name

  items = {
    username = "app_user"
    password = "super-secret-password-123"
    host     = "db.example.com"
    port     = "5432"
    database = "myapp"
  }
}

resource "nomad_variable" "api_keys" {
  path      = "secrets/api"
  namespace = nomad_namespace.development.name

  items = {
    stripe_key     = "sk_test_abc123"
    sendgrid_key   = "SG.xyz789"
    aws_access_key = "AKIAIOSFODNN7EXAMPLE"
    aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
}

resource "nomad_variable" "tls_certs" {
  path      = "secrets/tls"
  namespace = nomad_namespace.production.name

  items = {
    cert_pem = <<-EOT
      -----BEGIN CERTIFICATE-----
      MIICpDCCAYwCCQDU+pQ4P2WzSjANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
      b2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjAUMRIwEAYD
      VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7
      ... (truncated for example)
      -----END CERTIFICATE-----
    EOT
    key_pem  = <<-EOT
      -----BEGIN PRIVATE KEY-----
      MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7...
      ... (truncated for example)
      -----END PRIVATE KEY-----
    EOT
  }
}

resource "nomad_variable" "staging_secrets" {
  path      = "secrets/app"
  namespace = nomad_namespace.staging.name

  items = {
    jwt_secret  = "staging-jwt-secret-key"
    session_key = "staging-session-encryption-key"
    admin_email = "admin@staging.example.com"
  }
}

resource "nomad_variable" "production_secrets" {
  path      = "secrets/app"
  namespace = nomad_namespace.production.name

  items = {
    jwt_secret  = "production-jwt-secret-key-very-secure"
    session_key = "production-session-encryption-key"
    admin_email = "admin@example.com"
  }
}

output "secret_paths" {
  description = "Paths to access secrets in jobs"
  value = {
    development = {
      database = nomad_variable.db_credentials.path
      api      = nomad_variable.api_keys.path
    }
    staging = {
      app = nomad_variable.staging_secrets.path
    }
    production = {
      app = nomad_variable.production_secrets.path
      tls = nomad_variable.tls_certs.path
    }
  }
}

output "secret_usage_example" {
  description = "How to use secrets in a Nomad job"
  value       = <<-EOT
    # In your job spec, use the 'template' stanza:
    template {
      data        = "{{ with nomadVar \"secrets/database\" }}DB_USER={{ .username }}{{ end }}"
      destination = "secrets/env.txt"
      env         = true
    }
  EOT
}
