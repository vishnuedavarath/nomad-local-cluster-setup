# Nomad Autoscaler

Deploys `hashicorp/nomad-autoscaler` as a Nomad service job on the local
multipass cluster.

## Modes

| Mode | How to enable | Binary source |
| --- | --- | --- |
| Released (default) | nothing — just `terraform apply` | Downloaded inside the alloc via the `artifact` stanza from `releases.hashicorp.com`. The version is auto-resolved from the GitHub releases API unless pinned with `var.autoscaler_version`. |
| Local build | `-var use_local_binary=true` | Read from `var.local_binary_path` (default `~/projects/hashicorp/nomad-autoscaler/bin/nomad-autoscaler`) and `multipass transfer`'d to `/opt/nomad-autoscaler/nomad-autoscaler` on every client before the job is registered. |

## Usage

Default (latest released binary):

```sh
terraform init
terraform apply
```

Pin a released version:

```sh
terraform apply -var='autoscaler_version=0.4.7'
```

Use a locally built binary:

```sh
# Build first
( cd ~/projects/hashicorp/nomad-autoscaler && make dev )

terraform apply -var='use_local_binary=true'
```

## Notes

- The job uses the `raw_exec` driver, which is enabled by the cluster
  bootstrap (see `terraform/main.tf`).
- The autoscaler talks to Nomad using the bootstrap ACL token recorded in
  `terraform/.nomad_acl_bootstrap.json` unless overridden by `-var nomad_token=...`.
- Scaling policies are read from Nomad job `scaling` stanzas (the
  `webapp` workspace ships one out of the box).
