# Nomad Local Cluster

Provision a local HashiCorp Nomad cluster with Consul service discovery using Multipass VMs running Ubuntu 24.04 LTS.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        Local Machine                    │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ nomad-server │  │ nomad-server │  │ nomad-server │   │
│  │   (1GB RAM)  │  │   (1GB RAM)  │  │   (1GB RAM)  │   │
│  │          Nomad + Consul (server mode)            │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│         │                 │                 │           │
│         └─────────────────┼─────────────────┘           │
│                           │                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ nomad-client │  │ nomad-client │  │ nomad-client │   │
│  │   (2GB RAM)  │  │   (2GB RAM)  │  │   (2GB RAM)  │   │
│  │              Nomad + Consul + Docker             │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Choose Your Provisioning Approach

| Approach | Description | Guide |
|----------|-------------|-------|
| **Ansible** | Quick setup with playbooks | [ansible/README.md](ansible/README.md) |
| **Terraform** | Infrastructure as code with state management | [terraform/README.md](terraform/README.md) |

## Prerequisites

- **macOS** with Apple Silicon (ARM64)
- [Multipass](https://multipass.run/) installed

```bash
brew install --cask multipass
```

## Project Structure

```
nomad-local-cluster/
├── ansible/                    # Ansible-based provisioning
│   ├── README.md
│   └── setup-local-nomad.yml
├── terraform/                  # Terraform-based provisioning
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── jobs/                   # Deploy jobs via Terraform
├── jobs/                       # Nomad job definitions
│   ├── nginx.nomad
│   ├── foo.nomad.hcl
│   └── bar.nomad.hcl
└── README.md
```

## What Gets Installed

| Component | Server Nodes | Client Nodes |
|-----------|--------------|--------------|
| Nomad | Server mode (HA) | Client mode |
| Consul | Server mode | Client mode |
| Docker | - | ✓ |

## Quick Commands

```bash
# View cluster status
multipass list
nomad node status

# Stop/start cluster
multipass stop --all
multipass start --all

# Destroy cluster
multipass delete --all && multipass purge
```

## Web UIs

| Service | URL |
|---------|-----|
| Nomad | `http://<server-ip>:4646` |
| Consul | `http://<server-ip>:8500` |
