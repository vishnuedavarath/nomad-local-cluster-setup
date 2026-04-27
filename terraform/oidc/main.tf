terraform {
  required_version = ">= 1.5.0"

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
  }
}

data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

resource "random_password" "dex_client_secret" {
  length  = 32
  special = false
}

locals {
  nomad_address        = data.terraform_remote_state.cluster.outputs.nomad_ui_url
  client_names         = data.terraform_remote_state.cluster.outputs.client_names
  client_ips           = data.terraform_remote_state.cluster.outputs.client_ips
  identity_client_name = local.client_names[var.identity_client_index]
  identity_client_ip   = local.client_ips[var.identity_client_index]
  host_access_ip       = trimspace(var.host_access_ip) != "" ? trimspace(var.host_access_ip) : join(".", concat(slice(split(".", local.identity_client_ip), 0, 3), ["1"]))
  dex_runtime_dir      = "${path.module}/.dex"

  dex_password      = "nomad-admin-password"
  dex_password_hash = "$2y$10$uaHf2Q.dj9C/5y4Olmk/DOEqeuRUibBMk0u50nsKrZ1Ga.3D0HNfS"
  dex_bind_address  = var.dex_runtime == "host" ? local.host_access_ip : local.identity_client_ip
  dex_issuer_url    = "http://${local.dex_bind_address}:${var.dex_http_port}/dex"
  dex_client_id     = "nomad-local"
  allowed_redirect_uris = distinct(concat([
    "http://localhost:4649/oidc/callback",
    "http://127.0.0.1:4649/oidc/callback",
    "${local.nomad_address}/ui/settings/tokens",
    local.nomad_address,
  ], var.additional_redirect_uris))

  dex_config = yamlencode({
    issuer = local.dex_issuer_url
    storage = {
      type = "sqlite3"
      config = {
        file = "/opt/dex/dex.db"
      }
    }
    web = {
      http = "0.0.0.0:5556"
    }
    oauth2 = {
      skipApprovalScreen = true
    }
    enablePasswordDB = true
    staticClients = [
      {
        id           = local.dex_client_id
        name         = "Nomad Local Cluster"
        secret       = random_password.dex_client_secret.result
        redirectURIs = local.allowed_redirect_uris
      }
    ]
    staticPasswords = [
      {
        email    = var.oidc_admin_email
        hash     = local.dex_password_hash
        username = var.oidc_admin_username
        userID   = "nomad-local-admin"
      }
    ]
  })
}

resource "null_resource" "dex_container_host" {
  count = var.dex_runtime == "host" ? 1 : 0

  triggers = {
    runtime         = var.dex_runtime
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
    when = destroy

    command = <<-EOT
      set -euo pipefail

      docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      rm -rf ${self.triggers.runtime_dir}
    EOT
  }
}

resource "null_resource" "dex_container_vm" {
  count = var.dex_runtime == "vm" ? 1 : 0

  triggers = {
    client_name     = local.identity_client_name
    runtime         = var.dex_runtime
    container_name  = var.dex_container_name
    dex_config_hash = sha256(local.dex_config)
    dex_image       = var.dex_image
    dex_http_port   = tostring(var.dex_http_port)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      multipass exec ${self.triggers.client_name} -- sudo mkdir -p /opt/dex

      multipass exec ${self.triggers.client_name} -- bash -lc 'cat <<'"'"'EOF'"'"' | sudo tee /opt/dex/config.yaml >/dev/null
${local.dex_config}
EOF'

      multipass exec ${self.triggers.client_name} -- sudo docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      multipass exec ${self.triggers.client_name} -- sudo docker run -d \
        --name ${self.triggers.container_name} \
        --restart unless-stopped \
        -p ${self.triggers.dex_http_port}:5556 \
        -v /opt/dex:/opt/dex \
        ${self.triggers.dex_image} dex serve /opt/dex/config.yaml >/dev/null
    EOT
  }

  provisioner "local-exec" {
    when = destroy

    command = <<-EOT
      set -euo pipefail

      multipass exec ${self.triggers.client_name} -- sudo docker rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true
      multipass exec ${self.triggers.client_name} -- sudo rm -rf /opt/dex
    EOT
  }
}

resource "time_sleep" "wait_for_dex" {
  depends_on = [
    null_resource.dex_container_host,
    null_resource.dex_container_vm,
  ]

  create_duration = "10s"
}
