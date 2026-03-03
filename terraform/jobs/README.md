# Nomad Jobs - Terraform

Deploy jobs to an existing Nomad cluster using Terraform.

## Prerequisites

- Running Nomad cluster (provisioned via `../` with `terraform apply`)
- Cluster terraform state must exist at `../terraform.tfstate`

## Usage

```bash
# Initialize
terraform init

# Deploy jobs (automatically reads Nomad address from cluster state)
terraform apply

# Destroy jobs (stops them in Nomad)
terraform destroy
```

## How It Works

This module uses `terraform_remote_state` to read the `nomad_ui_url` output from the parent cluster's state file. No manual input required!

## Adding More Jobs

Add additional `nomad_job` resources:

```hcl
resource "nomad_job" "my_app" {
  jobspec = file("${path.module}/../../jobs/my_app.nomad.hcl")
}
```
