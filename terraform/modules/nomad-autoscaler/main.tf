# Module: nomad-autoscaler
# Deploys the Nomad Autoscaler (released or local binary).

terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# --------------------------------------------------------------------------- #
# Resolve version                                                              #
# --------------------------------------------------------------------------- #

data "http" "latest_release" {
  count = var.use_local_binary || var.autoscaler_version != "" ? 0 : 1
  url   = "https://api.github.com/repos/hashicorp/nomad-autoscaler/releases/latest"

  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

locals {
  resolved_version = var.use_local_binary ? "local" : (
    var.autoscaler_version != "" ?
    var.autoscaler_version :
    trimprefix(jsondecode(data.http.latest_release[0].response_body).tag_name, "v")
  )

  local_binary_abs_path = pathexpand(var.local_binary_path)
  local_binary_hash     = var.use_local_binary && fileexists(local.local_binary_abs_path) ? filemd5(local.local_binary_abs_path) : ""
}

# --------------------------------------------------------------------------- #
# Upload local binary to clients                                               #
# --------------------------------------------------------------------------- #

resource "null_resource" "upload_binary" {
  for_each = var.use_local_binary ? toset(var.client_names) : toset([])

  triggers = {
    client_name  = each.key
    binary_path  = local.local_binary_abs_path
    binary_mtime = local.local_binary_hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ ! -f "${local.local_binary_abs_path}" ]; then
        echo "ERROR: local autoscaler binary not found at ${local.local_binary_abs_path}" >&2
        exit 1
      fi
      multipass exec ${each.key} -- sudo mkdir -p /opt/nomad-autoscaler
      multipass transfer "${local.local_binary_abs_path}" ${each.key}:/tmp/nomad-autoscaler
      multipass exec ${each.key} -- sudo install -m 0755 /tmp/nomad-autoscaler /opt/nomad-autoscaler/nomad-autoscaler
      multipass exec ${each.key} -- rm -f /tmp/nomad-autoscaler
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Deploy autoscaler job                                                        #
# --------------------------------------------------------------------------- #

resource "nomad_job" "autoscaler" {
  detach = true
  jobspec = templatefile(var.job_template_path, {
    namespace        = var.namespace
    datacenter       = var.datacenter
    use_local_binary = var.use_local_binary
    local_binary     = "/opt/nomad-autoscaler/nomad-autoscaler"
    autoscaler_ver   = local.resolved_version
    binary_hash      = local.local_binary_hash
    nomad_address    = var.nomad_address
    nomad_token      = var.nomad_token
  })

  depends_on = [null_resource.upload_binary]
}
