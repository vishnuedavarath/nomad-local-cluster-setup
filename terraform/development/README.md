# Nomad Development Workloads - Terraform

Deploy sample or development-focused Nomad jobs against an existing local cluster.

This workspace is intentionally limited to workload deployment so it does not mix cluster operations with application-level changes.

## Prerequisites

- Running Nomad cluster provisioned from `../`
- Cluster state available at `../terraform.tfstate`

## Usage

```bash
cd development
terraform init
terraform apply
```

To add more development workloads, define additional `nomad_job` resources that reference jobspec files from `../../jobs/`.