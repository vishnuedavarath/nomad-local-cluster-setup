# Nomad Local Cluster

An Ansible playbook to provision a local HashiCorp Nomad cluster with Consul service discovery using Multipass VMs running Ubuntu 24.04 LTS.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        Local Machine                    │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ nomad-server │  │ nomad-server │  │ nomad-server │   │
│  │   (1GB RAM)  │  │   (1GB RAM)  │  │   (1GB RAM)  │   │
│  │          Nomad + Consul (server mode)            |   |
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│         │                 │                 │           │
│         └─────────────────┼─────────────────┘           │
│                           │                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ nomad-client │  │ nomad-client │  │ nomad-client │   │
│  │   (2GB RAM)  │  │   (2GB RAM)  │  │   (2GB RAM)  │   │
│  │              Nomad + Consul + Docker             |   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- **macOS** with Apple Silicon (ARM64)
- [Multipass](https://multipass.run/) installed
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed

```bash
# Install Multipass
brew install --cask multipass

# Install Ansible
brew install ansible
```

## Quick Start

```bash
# Run the playbook
ansible-playbook setup-local-nomad.yml

# After completion, use the IP shown in output to access the UIs
# Set the Nomad address (replace <server-ip> with actual IP from output)
export NOMAD_ADDR=http://<server-ip>:4646

# Open the Nomad UI
open http://<server-ip>:4646
```

## Configuration

Edit the variables at the top of `setup-local-nomad.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `server_count` | 3 | Number of Nomad server nodes |
| `client_count` | 3 | Number of Nomad client nodes |

### Resource Allocation

| Node Type | CPUs | Memory | Disk |
|-----------|------|--------|------|
| Server | 1 | 1GB | 5GB |
| Client | 1 | 2GB | 10GB |

## What Gets Installed

### All Nodes
- HashiCorp Nomad
- HashiCorp Consul

### Server Nodes
- Nomad in server mode (HA cluster with leader election)
- Consul in server mode (for service discovery)

### Client Nodes
- Nomad in client mode (job execution)
- Consul in client mode (service registration)
- Docker (container runtime)

## Running Jobs

Once the cluster is up, you can deploy jobs:

```bash
# Using the included nginx example
nomad run nginx.nomad

# Or use nomad-pack for templated deployments
nomad-pack run nginx
```

## Managing the Cluster

### View cluster status
```bash
# List all VMs
multipass list

# Check Nomad status
nomad server members
nomad node status
```

### Stop the cluster
```bash
multipass stop --all
```

### Start the cluster
```bash
multipass start --all
```

### Destroy the cluster
```bash
multipass delete --all && multipass purge
```

## Troubleshooting

### Re-running after VM restart

If VMs get new IPs after restart, re-run the playbook to update configurations:

```bash
ansible-playbook setup-local-nomad.yml
```

For a clean restart (wipe state):

```bash
for vm in $(multipass list --format csv | tail -n +2 | cut -d',' -f1); do
  multipass exec $vm -- sudo rm -rf /opt/consul/data/* /opt/nomad/data/*
done
ansible-playbook setup-local-nomad.yml
```

### Check service logs

```bash
# Nomad logs
multipass exec <vm-name> -- sudo journalctl -u nomad -f

# Consul logs
multipass exec <vm-name> -- sudo journalctl -u consul -f
```

### SSH into a VM

```bash
multipass shell <vm-name>
```

## Accessing UIs

| Service | URL |
|---------|-----|
| Nomad | `http://<server-ip>:4646` |
| Consul | `http://<server-ip>:8500` |

Replace `<server-ip>` with the IP address shown in the playbook output.
