# Module: nomad-oidc
# Runs a Dex OIDC provider for Nomad authentication.

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

resource "random_password" "dex_client_secret" {
  length  = 32
  special = false
}

locals {
  identity_client_name = var.client_names[var.identity_client_index]
  identity_client_ip   = var.client_ips[var.identity_client_index]
  host_access_ip       = trimspace(var.host_access_ip) != "" ? trimspace(var.host_access_ip) : join(".", concat(slice(split(".", local.identity_client_ip), 0, 3), ["1"]))
  dex_bind_address     = var.dex_runtime == "host" ? local.host_access_ip : local.identity_client_ip
  dex_issuer_url       = "http://${local.dex_bind_address}:${var.dex_http_port}/dex"
  dex_runtime_dir      = "${path.module}/.dex"

  allowed_redirect_uris = distinct(concat([
    "http://localhost:4649/oidc/callback",
    "http://127.0.0.1:4649/oidc/callback",
    "${var.nomad_address}/ui/settings/tokens",
    var.nomad_address,
  ], var.additional_redirect_uris))

  dex_config = yamlencode({
    issuer = local.dex_issuer_url
    storage = {
      type   = "sqlite3"
      config = { file = "/opt/dex/dex.db" }
    }
    web              = { http = "0.0.0.0:5556" }
    oauth2           = { skipApprovalScreen = true }
    enablePasswordDB = true
    staticClients = [{
      id           = var.dex_client_id
      name         = "Nomad Local Cluster"
      secret       = random_password.dex_client_secret.result
      redirectURIs = local.allowed_redirect_uris
    }]
    staticPasswords = [{
      email    = var.oidc_admin_email
      hash     = var.oidc_admin_password_hash
      username = var.oidc_admin_username
      userID   = "nomad-local-admin"
    }]
  })
}

# --------------------------------------------------------------------------- #
# Dex on host (Docker on macOS)                                                #
# --------------------------------------------------------------------------- #

resource "null_resource" "dex_host" {
  count = var.dex_runtime == "host" ? 1 : 0

  triggers = {
    container_name  = var.dex_container_name
    dex_config_hash = sha256(local.dex_config)
    dex_image       = var.dex_image
    dex_http_port   = tostring(var.dex_http_port)
    runtime_dir     = local.dex_runtime_dir
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      mkdir -p ${self.triggers.runtime_dir}
      cat > ${self.triggers.runtime_dir}/config.yaml <<'EOF'
${local.dex_config}
EOF
      docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      docker run -d \
        --name ${self.triggers.container_name} \
        --restart unless-stopped \
        -p ${self.triggers.dex_http_port}:5556 \
        -v ${self.triggers.runtime_dir}:/opt/dex \
        ${self.triggers.dex_image} dex serve /opt/dex/config.yaml >/dev/null
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      rm -rf ${self.triggers.runtime_dir}
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Dex on VM (Docker inside Multipass)                                          #
# --------------------------------------------------------------------------- #

resource "null_resource" "dex_vm" {
  count = var.dex_runtime == "vm" ? 1 : 0

  triggers = {
    client_name     = local.identity_client_name
    container_name  = var.dex_container_name
    dex_config_hash = sha256(local.dex_config)
    dex_image       = var.dex_image
    dex_http_port   = tostring(var.dex_http_port)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${self.triggers.client_name}"

      multipass exec $VM -- sudo mkdir -p /opt/dex
      multipass exec $VM -- bash -lc 'cat <<'"'"'EOF'"'"' | sudo tee /opt/dex/config.yaml >/dev/null
${local.dex_config}
EOF'
      multipass exec $VM -- sudo docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      multipass exec $VM -- sudo docker run -d \
        --name ${self.triggers.container_name} \
        --restart unless-stopped \
        -p ${self.triggers.dex_http_port}:5556 \
        -v /opt/dex:/opt/dex \
        ${self.triggers.dex_image} dex serve /opt/dex/config.yaml >/dev/null
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      multipass exec ${self.triggers.client_name} -- sudo docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      multipass exec ${self.triggers.client_name} -- sudo rm -rf /opt/dex
    EOT
  }
}

resource "time_sleep" "wait_for_dex" {
  depends_on      = [null_resource.dex_host, null_resource.dex_vm]
  create_duration = "10s"
}

# --------------------------------------------------------------------------- #
# Nomad ACL Auth Method (OIDC)                                                 #
# --------------------------------------------------------------------------- #

resource "nomad_acl_auth_method" "dex" {
  count = var.create_auth_method ? 1 : 0

  name              = var.auth_method_name
  type              = "OIDC"
  token_locality    = "global"
  max_token_ttl     = var.auth_method_max_token_ttl
  token_name_format = "$${auth_method_type}-$${value.email}"
  default           = var.make_default_auth_method

  config {
    oidc_discovery_url    = local.dex_issuer_url
    oidc_client_id        = var.dex_client_id
    oidc_client_secret    = random_password.dex_client_secret.result
    oidc_disable_userinfo = true
    oidc_scopes           = ["openid", "profile", "email"]
    bound_audiences       = [var.dex_client_id]
    allowed_redirect_uris = local.allowed_redirect_uris
    claim_mappings = {
      email              = "email"
      preferred_username = "username"
    }
  }

  depends_on = [time_sleep.wait_for_dex]
}

# --------------------------------------------------------------------------- #
# Binding Rule: grant admin access to the Dex admin user                       #
# --------------------------------------------------------------------------- #

resource "nomad_acl_binding_rule" "admin" {
  count = var.create_auth_method ? 1 : 0

  auth_method = nomad_acl_auth_method.dex[0].name
  description = "Grant management access to the Dex admin user"
  selector    = "value.email == \"${var.oidc_admin_email}\""
  bind_type   = "management"
  bind_name   = ""
}

# --------------------------------------------------------------------------- #
# Additional binding rules from variable                                       #
# --------------------------------------------------------------------------- #

resource "nomad_acl_binding_rule" "custom" {
  for_each = var.create_auth_method ? var.binding_rules : {}

  auth_method = nomad_acl_auth_method.dex[0].name
  description = each.value.description
  selector    = each.value.selector
  bind_type   = each.value.bind_type
  bind_name   = each.value.bind_name
}
