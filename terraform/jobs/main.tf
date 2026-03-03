terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

# Read the cluster state to get the Nomad address
data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  nomad_address = data.terraform_remote_state.cluster.outputs.nomad_ui_url
}

provider "nomad" {
  address = local.nomad_address
}

# Deploy the nginx job
resource "nomad_job" "nginx" {
  jobspec = file("${path.module}/../../jobs/nginx.nomad")
}
