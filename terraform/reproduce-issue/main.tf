terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1.0"
    }
  }
}

provider "nomad" {
  address = "http://localhost:4646"
}

data "nomad_job_parser" "job" {
  hcl = <<-EOJ
    variable "greeting" {
      type = string
    }
    job "hello" {
      type = "batch"
      group "hello" {
        task "hello" {
          driver = "raw_exec"
          config {
            command = "/bin/echo"
            args = [var.greeting]
          }
        }
      }
    }
  EOJ

  # Not available:
  # vars = ...
}

output "parsed_job" {
  value = data.nomad_job_parser.job.json
}
