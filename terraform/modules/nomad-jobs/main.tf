# Module: nomad-jobs
# Deploys Nomad jobs from jobspec files or templates.

terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}

# --------------------------------------------------------------------------- #
# Plain jobspec files                                                          #
# --------------------------------------------------------------------------- #

resource "nomad_job" "plain" {
  for_each = var.jobs

  detach  = true
  jobspec = file(each.value)
}

# --------------------------------------------------------------------------- #
# Templated jobspec files                                                      #
# --------------------------------------------------------------------------- #

resource "nomad_job" "templated" {
  for_each = var.templated_jobs

  detach  = true
  jobspec = templatefile(each.value.template_path, each.value.vars)
}
