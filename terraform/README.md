# Nomad Local Cluster - Terraform

This Terraform configuration provisions a local Nomad + Consul cluster using Multipass VMs.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Multipass](https://multipass.run/) installed and running
- Sufficient system resources (3 servers + 3 clients by default)

## Usage

```bash
# Initialize Terraform
terraform init

# Option 1: export the Enterprise license contents directly
export TF_VAR_nomad_enterprise_license='YOUR_LICENSE_CONTENTS'

# Option 2: point Terraform at an existing .hclic file
export TF_VAR_nomad_enterprise_license_file="$HOME/licenses/nomad-enterprise.hclic"

# Preview changes
terraform plan

# Apply configuration
terraform apply

# Destroy cluster
terraform destroy
```

## Configuration

Customize the cluster by creating a `terraform.tfvars` file:

```hcl
server_count  = 3
client_count  = 3
datacenter    = "dc1"
server_cpus   = 1
server_memory = "1G"
server_disk   = "5G"
client_cpus   = 1
client_memory = "2G"
client_disk   = "10G"
nomad_edition = "enterprise"
nomad_version = "1.11.3"
nomad_enterprise_license_file = "~/licenses/nomad-enterprise.hclic"
```

When `nomad_edition = "enterprise"`, provide either `nomad_enterprise_license` or `nomad_enterprise_license_file`. The root module reads the license from your local machine, installs the `+ent` binary from the HashiCorp releases site, and writes the license to each server at `/etc/nomad.d/license.hclic` by default.

## Outputs

After `terraform apply`, you'll see:

- **nomad_ui_url**: URL to access the Nomad UI
- **consul_ui_url**: URL to access the Consul UI  
- **nomad_addr_export**: Command to set `NOMAD_ADDR` environment variable

## Architecture

- **3 Nomad Server VMs**: Run Nomad and Consul in server mode (HA cluster)
- **3 Nomad Client VMs**: Run Nomad and Consul in client mode with Docker

## Upgrading an Existing OSS Cluster

This module now defaults to Nomad Enterprise. For an existing OSS cluster, provide the license contents or a local `.hclic` file and run `terraform apply` from the root module. The install resources are version-triggered, so Terraform will stop Nomad, replace the binary with the Enterprise release, write the server license file, and restart the cluster with the Enterprise binary.

## Running Jobs

After the cluster is up:

```bash
# Set the Nomad address (use the output from terraform apply)
export NOMAD_ADDR=http://<server-ip>:4646

# Run the nginx job
nomad job run ../jobs/nginx.nomad
```

## Additional Terraform Workspaces

The Terraform layout is separated by responsibility:

- `./` provisions the local Nomad and Consul cluster
- `operations/` manages shared namespaces, ACLs, secrets, and host volumes
- `development/` deploys sample or development workloads
- `oidc/` runs a local Dex OIDC provider in Docker on a client VM and outputs the values needed for a separate Nomad ACL auth method config

Deploy operational configuration:

```bash
cd operations
terraform init
terraform apply
```

Deploy development workloads:

```bash
cd development
terraform init
terraform apply
```

Deploy local OIDC separately:

```bash
cd oidc
terraform init
terraform apply
```

See [oidc/README.md](oidc/README.md) and [development/README.md](development/README.md) for details.

## Troubleshooting

### Check Service Logs

```bash
multipass exec <vm-name> -- sudo journalctl -u nomad -f
multipass exec <vm-name> -- sudo journalctl -u consul -f
```

### SSH into a VM

```bash
multipass shell <vm-name>
```
