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
datacenter    = "local-dc"
server_cpus   = 1
server_memory = "1G"
server_disk   = "5G"
client_cpus   = 1
client_memory = "2G"
client_disk   = "10G"
```

## Outputs

After `terraform apply`, you'll see:

- **nomad_ui_url**: URL to access the Nomad UI
- **consul_ui_url**: URL to access the Consul UI  
- **nomad_addr_export**: Command to set `NOMAD_ADDR` environment variable

## Architecture

- **3 Nomad Server VMs**: Run Nomad and Consul in server mode (HA cluster)
- **3 Nomad Client VMs**: Run Nomad and Consul in client mode with Docker

## Running Jobs

After the cluster is up:

```bash
# Set the Nomad address (use the output from terraform apply)
export NOMAD_ADDR=http://<server-ip>:4646

# Run the nginx job
nomad job run ../jobs/nginx.nomad
```

## Deploy Jobs via Terraform

You can also deploy jobs using the separate Terraform configuration:

```bash
cd jobs
terraform init
terraform apply
```

See [jobs/README.md](jobs/README.md) for details.

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
