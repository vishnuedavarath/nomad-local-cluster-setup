terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

# Nomad ACL token (management token for creating resources)
# Set via: export TF_VAR_nomad_token="<token>"
variable "nomad_token" {
  description = "Nomad ACL token (management token)"
  type        = string
  sensitive   = true
  default     = ""
}

# Read the cluster state to get the Nomad address.
data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  nomad_address             = data.terraform_remote_state.cluster.outputs.nomad_ui_url
  bootstrap_token_file      = "${path.module}/../.nomad_acl_bootstrap.json"
  bootstrap_token_from_file = fileexists(local.bootstrap_token_file) ? try(jsondecode(file(local.bootstrap_token_file)).SecretID, "") : ""

  cluster_nomad_token_raw = try(data.terraform_remote_state.cluster.outputs.acl_bootstrap_token, "")
  cluster_nomad_token     = local.cluster_nomad_token_raw == "Bootstrap failed or already done" ? "" : local.cluster_nomad_token_raw

  effective_nomad_token = var.nomad_token != "" ? var.nomad_token : (
    local.bootstrap_token_from_file != "" ? local.bootstrap_token_from_file : local.cluster_nomad_token
  )
}

provider "nomad" {
  address   = local.nomad_address
  secret_id = local.effective_nomad_token != "" ? local.effective_nomad_token : null
}

# Deploy the sample nginx job.
resource "nomad_job" "nginx" {
  detach  = true
  jobspec = file("${path.module}/../../jobs/nginx.nomad")
}
