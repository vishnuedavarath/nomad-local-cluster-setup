# Nomad Local Cluster - Ansible

Ansible playbook to provision a local HashiCorp Nomad cluster with Consul service discovery using Multipass VMs.

## Prerequisites

- [Multipass](https://multipass.run/) installed
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed

```bash
brew install --cask multipass
brew install ansible
```

## Quick Start

```bash
ansible-playbook setup-local-nomad.yml
```

After completion, the playbook outputs the UI URLs and `NOMAD_ADDR` export command.

## Configuration

Edit variables at the top of `setup-local-nomad.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `server_count` | 3 | Number of Nomad server nodes |
| `client_count` | 3 | Number of Nomad client nodes |

### Resource Allocation

| Node Type | CPUs | Memory | Disk |
|-----------|------|--------|------|
| Server | 1 | 1GB | 5GB |
| Client | 1 | 2GB | 10GB |

## Running Jobs

```bash
# Set Nomad address (use IP from playbook output)
export NOMAD_ADDR=http://<server-ip>:4646

# Run nginx example
nomad job run ../jobs/nginx.nomad
```

## Re-running After Changes

```bash
# Re-run playbook (updates configurations)
ansible-playbook setup-local-nomad.yml

# Clean restart (wipe state)
for vm in $(multipass list --format csv | tail -n +2 | cut -d',' -f1); do
  multipass exec $vm -- sudo rm -rf /opt/consul/data/* /opt/nomad/data/*
done
ansible-playbook setup-local-nomad.yml
```

## Troubleshooting

### Check Service Logs

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

## Destroy Cluster

```bash
multipass delete --all && multipass purge
```
