terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

# The Nomad provider reads NOMAD_ADDR and NOMAD_TOKEN from the environment
# automatically, so no explicit address/secret_id is needed here.
provider "nomad" {}

# --------------------------------------------------------------------------- #
# Render and deploy the jobspec                                                #
# --------------------------------------------------------------------------- #

locals {
  webapp_jobspec = templatefile("${path.module}/../../jobs/webapp.nomad.hcl.tftpl", {
    namespace      = var.namespace
    datacenter     = var.datacenter
    image          = var.image
    replicas       = var.replicas
    service_name   = var.service_name
    enable_scaling = var.enable_scaling
    min_count      = var.min_count
    max_count      = var.max_count
    target_cpu_pct = var.target_cpu_pct
  })

  fabio_jobspec = templatefile("${path.module}/../../jobs/fabio.nomad.hcl.tftpl", {
    namespace  = var.namespace
    datacenter = var.datacenter
  })
}

resource "nomad_job" "webapp" {
  detach  = true
  jobspec = local.webapp_jobspec
}

# Optional: small Fabio LB job that fronts every Consul service tagged
# `urlprefix-/`. Disabled by default — Consul service discovery is the
# primary mechanism for routing requests to webapp instances.
resource "nomad_job" "fabio" {
  count   = var.deploy_fabio_lb ? 1 : 0
  detach  = true
  jobspec = local.fabio_jobspec
}
