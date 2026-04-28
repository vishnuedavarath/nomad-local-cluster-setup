terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# --------------------------------------------------------------------------- #
# Remote state lookups                                                         #
# --------------------------------------------------------------------------- #

data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  nomad_address             = data.terraform_remote_state.cluster.outputs.nomad_ui_url
  client_names              = try(data.terraform_remote_state.cluster.outputs.client_names, [])
  bootstrap_token_file      = "${path.module}/../.nomad_acl_bootstrap.json"
  bootstrap_token_from_file = fileexists(local.bootstrap_token_file) ? try(jsondecode(file(local.bootstrap_token_file)).SecretID, "") : ""

  cluster_nomad_token_raw = try(data.terraform_remote_state.cluster.outputs.acl_bootstrap_token, "")
  cluster_nomad_token     = local.cluster_nomad_token_raw == "Bootstrap failed or already done" ? "" : local.cluster_nomad_token_raw

  effective_nomad_token = var.nomad_token != "" ? var.nomad_token : (
    local.bootstrap_token_from_file != "" ? local.bootstrap_token_from_file : local.cluster_nomad_token
  )
}

# The Nomad provider reads NOMAD_ADDR and NOMAD_TOKEN from the environment
# automatically, so no explicit address/secret_id is needed here.
provider "nomad" {}

# --------------------------------------------------------------------------- #
# Resolve the autoscaler version to deploy                                     #
# --------------------------------------------------------------------------- #
# When `var.autoscaler_version` is empty, query the GitHub releases API for
# the latest tag. Otherwise use the pinned value verbatim.

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

  # Hash of the local binary, baked into the jobspec so a rebuilt binary
  # produces a real diff in `nomad_job.autoscaler` and triggers a rolling
  # restart of the alloc. Empty when not using a local binary.
  local_binary_hash = var.use_local_binary && fileexists(local.local_binary_abs_path) ? filemd5(local.local_binary_abs_path) : ""
}

# --------------------------------------------------------------------------- #
# Local-binary mode: ship the binary to every Nomad client                     #
# --------------------------------------------------------------------------- #

resource "null_resource" "upload_local_binary" {
  for_each = var.use_local_binary ? toset(local.client_names) : toset([])

  triggers = {
    client_name  = each.key
    binary_path  = local.local_binary_abs_path
    binary_mtime = fileexists(local.local_binary_abs_path) ? filemd5(local.local_binary_abs_path) : ""
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ ! -f "${local.local_binary_abs_path}" ]; then
        echo "ERROR: local autoscaler binary not found at ${local.local_binary_abs_path}" >&2
        echo "Build it first or set use_local_binary=false." >&2
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
# Render and deploy the jobspec                                                #
# --------------------------------------------------------------------------- #

locals {
  jobspec = templatefile("${path.module}/../../jobs/autoscaler.nomad.hcl.tftpl", {
    namespace        = var.namespace
    datacenter       = var.datacenter
    use_local_binary = var.use_local_binary
    local_binary     = "/opt/nomad-autoscaler/nomad-autoscaler"
    autoscaler_ver   = local.resolved_version
    binary_hash      = local.local_binary_hash
    nomad_address    = local.nomad_address
    nomad_token      = local.effective_nomad_token
  })
}

resource "nomad_job" "autoscaler" {
  detach  = true
  jobspec = local.jobspec

  depends_on = [null_resource.upload_local_binary]
}
