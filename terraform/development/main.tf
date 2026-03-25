terraform {
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
  nomad_address = data.terraform_remote_state.cluster.outputs.nomad_ui_url
  nomad_token   = try(data.terraform_remote_state.cluster.outputs.acl_bootstrap_token, "")
}

provider "nomad" {
  address   = local.nomad_address
  secret_id = var.nomad_token != "" ? var.nomad_token : (local.nomad_token != "" ? local.nomad_token : null)
}

# Deploy the sample nginx job.
resource "nomad_job" "nginx" {
  detach  = true
  jobspec = file("${path.module}/../../jobs/nginx.nomad")
}
