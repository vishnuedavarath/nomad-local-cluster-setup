# Nomad Local Cluster - Terraform

Modular, fully configurable Terraform setup for running a Nomad + Consul cluster on local Multipass VMs.

## Architecture

```
terraform/
├── environments/
│   └── local/                    # Root config (compose modules here)
│       ├── main.tf               # Module composition & providers
│       ├── variables.tf          # All input variables
│       ├── outputs.tf            # Cluster outputs
│       ├── versions.tf           # Provider version constraints
│       ├── terraform.tfvars      # YOUR configuration (edit this)
│       └── terraform.tfvars.example  # Documented example with all options
└── modules/
    ├── multipass-instances/      # VM lifecycle only (launch/destroy)
    ├── nomad-cluster/            # Install & configure Nomad + Consul
    ├── nomad-acl/                # ACL policies & tokens (ops, admin, etc.)
    ├── nomad-namespaces/         # Namespace management
    ├── nomad-secrets/            # Nomad Variables (secret storage)
    ├── nomad-volumes/            # Host volume setup on clients
    ├── nomad-plugins/            # Plugin infrastructure (mount dirs, device/driver binaries)
    └── nomad-oidc/               # Dex OIDC provider + auth method
```

## Key Design Principles

1. **Decoupled phases**: VM provisioning (`multipass-instances`) is completely separate from cluster setup (`nomad-cluster`) and Nomad configuration (ACL, namespaces, jobs, etc.)
2. **Everything configurable via tfvars**: All values (VM specs, versions, features, namespaces, volumes, secrets, OIDC) are in `terraform.tfvars`
3. **Feature toggles**: Each capability (`enable_acl`, `enable_oidc`, `enable_autoscaler`, etc.) can be independently enabled/disabled
4. **Two-phase apply**: Infrastructure first, then Nomad configuration
5. **Ops token for operations**: Bootstrap/admin tokens are reserved for ACL management; an ops token is used for day-to-day operations (autoscaler, exported `NOMAD_TOKEN`)

## Quick Start

```bash
cd environments/local

# Copy example config and customize
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to your needs

# Initialize
terraform init

# Phase 1: Launch VMs and bootstrap the cluster
terraform apply -target=module.instances -target=module.cluster

# Phase 2: Enable Nomad-dependent modules
# Edit terraform.tfvars: set enable_nomad_setup = true
terraform apply
```

## Deploy Jobs

Jobs are deployed using the Nomad CLI via deploy scripts (not Terraform). This keeps job lifecycle decoupled from infrastructure.

```bash
# Deploy all jobs in nomad-jobs/
./scripts/deploy-jobs.sh

# Deploy specific jobs
./scripts/deploy-jobs.sh nginx.nomad foo.nomad.hcl

# Deploy CSI plugins (after Terraform has prepared mount dirs)
./scripts/deploy-csi-plugins.sh

# Check status
nomad job status
nomad plugin status
```

Job specs live in `nomad-jobs/` at the repo root. CSI plugin jobs live in `nomad-jobs/csi/`. Templates (`.tftpl` files) are skipped by the deploy script — render them manually with `nomad job run -var` or convert them to plain HCL with defaults.

## Configuration

Edit `environments/local/terraform.tfvars` to customize. See `terraform.tfvars.example` for a fully documented template.

| Section | What it controls |
|---------|-----------------|
| VM Infrastructure | VM count, resources (CPU/RAM/disk), image, name prefixes |
| Cluster Configuration | Datacenter, Nomad version/edition, ACL, Docker, delays |
| Feature Toggles | Enable/disable each module independently |
| Namespaces | Map of namespaces with descriptions and metadata |
| Host Volumes | Map of host volumes with paths and permissions |
| Secrets | Nomad Variables to store in specific namespaces |
| Custom ACL Policies | Additional ACL policies beyond built-in defaults |
| OIDC | Dex runtime, admin credentials, auth method, binding rules |

## Module Dependency Graph

```
multipass-instances
       │
       ▼
  nomad-cluster
       │
       ├──► nomad-acl
       ├──► nomad-namespaces ──► nomad-secrets
       ├──► nomad-volumes
       ├──► nomad-plugins (depends on cluster)
       └──► nomad-oidc (depends on acl + cluster)
```

**Jobs** are deployed separately via CLI using `./scripts/deploy-jobs.sh` (not Terraform).
See the `nomad-jobs/` directory for job definitions.

## Token Hierarchy

When ACL is enabled, the following tokens are created:

| Token | Purpose | Used by |
|-------|---------|---------|
| Bootstrap | Initial cluster token, written to `.nomad_acl_bootstrap.json` | Nomad provider auth |
| Admin | Full management access | ACL administration |
| Ops | Operational access (read/write jobs, nodes) | Autoscaler, exported `NOMAD_TOKEN` |
| Developer | Scoped to development namespaces | Dev workflows |
| Readonly | Read-only cluster access | Monitoring |

## OIDC Authentication

When `enable_oidc = true`, the module:

1. Deploys a [Dex](https://dexidp.io/) OIDC identity provider (Docker container on host or VM)
2. Creates a `nomad_acl_auth_method` pointing to Dex
3. Sets up binding rules (admin user → management token, plus custom rules)

Configure via tfvars:

```hcl
enable_oidc                    = true
oidc_create_auth_method        = true
oidc_auth_method_name          = "local-dex"
oidc_auth_method_max_token_ttl = "8h"
oidc_make_default_auth_method  = true

# Additional binding rules
oidc_binding_rules = {
  developers = {
    description = "Map engineering group to developer policy"
    selector    = "\"engineering\" in list.groups"
    bind_type   = "policy"
    bind_name   = "developer"
  }
}
```

Login with: `nomad login -method=local-dex -oidc-callback-addr=localhost:4649`

## Examples

### Minimal cluster (3 servers, 1 client, no ACL)

```hcl
server_count       = 3
client_count       = 1
enable_acl         = false
enable_nomad_setup = true
enable_jobs        = false
enable_autoscaler  = false
enable_oidc        = false
```

### Enterprise with OIDC

```hcl
nomad_edition                 = "enterprise"
nomad_enterprise_license_file = "~/licenses/nomad-enterprise.hclic"
enable_acl                    = true
enable_oidc                   = true
enable_nomad_setup            = true
```

### Custom namespaces and volumes

```hcl
namespaces = {
  team-alpha = {
    description = "Team Alpha workspace"
    meta        = { team = "alpha" }
  }
  team-beta = {
    description = "Team Beta workspace"
    meta        = { team = "beta" }
  }
}

host_volumes = {
  postgres-data = {
    path        = "/opt/nomad/volumes/postgres"
    read_only   = false
    permissions = "700"
  }
  shared-cache = {
    path        = "/opt/nomad/volumes/cache"
    read_only   = false
    permissions = "777"
  }
}
```

## Outputs

After apply, useful outputs are available:

```bash
terraform output nomad_ui_url          # Nomad UI address
terraform output nomad_token_export    # export NOMAD_TOKEN=... (ops token)
terraform output ops_token             # Ops token value (sensitive)
terraform output -json oidc_issuer_url # OIDC issuer URL
```
