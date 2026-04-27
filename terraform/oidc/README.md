# Local OIDC for Nomad

This Terraform stack runs a local Dex identity provider in Docker.

Keeping it under `terraform/oidc` means you can create or destroy the local identity server without touching the main cluster state or any separate Nomad ACL auth-method state.

## What It Creates

- A Dex container on macOS Docker by default
- Optional VM runtime if you set `dex_runtime = "vm"`
- Outputs with the exact values needed for a separate `nomad_acl_auth_method` resource
- Outputs with the exact values needed for a separate `nomad_acl_binding_rule` resource

## Prerequisites

- The root cluster in `terraform/` has already been applied
- Multipass is running on the host
- Docker is installed on macOS if you use the default `dex_runtime = "host"`

## Apply

```bash
cd terraform/oidc
terraform init
terraform apply
```

By default Dex runs on the host and publishes on `0.0.0.0:${var.dex_http_port}`. The Multipass VMs in this repo currently route to the host through `192.168.2.1`, so the Dex issuer becomes `http://192.168.2.1:5556/dex` unless you override `host_access_ip`.

If you want the old behavior instead:

```hcl
dex_runtime = "vm"
```

After apply, inspect the generated credentials:

```bash
terraform output -raw oidc_admin_email
terraform output -raw oidc_admin_password
terraform output -json nomad_acl_auth_method_inputs | jq
terraform output -json nomad_acl_binding_rule_management_inputs | jq
```

If you want ready-to-copy HCL for a separate ACL stack:

```bash
terraform output -raw nomad_acl_auth_method_hcl
terraform output -raw nomad_acl_binding_rule_management_hcl
```

## Separate Nomad ACL Config

Create the Nomad auth method and binding rule in a different Terraform folder or config using the outputs from this stack.

Relevant outputs:

- `dex_runtime`
- `dex_host_access_ip`
- `dex_issuer_url`
- `dex_client_id`
- `dex_client_secret`
- `nomad_acl_auth_method_inputs`
- `nomad_acl_binding_rule_management_inputs`
- `nomad_acl_auth_method_hcl`
- `nomad_acl_binding_rule_management_hcl`

After that separate config is applied, make sure `NOMAD_ADDR` points at your cluster and run:

```bash
export NOMAD_ADDR=$(cd .. && terraform output -raw nomad_ui_url)
nomad login -method=local-dex -oidc-callback-addr=localhost:4649
```

Default built-in local credentials:

- Email: `nomad-admin@example.com`
- Password: `nomad-admin-password`

Dex is exposed at the value of `dex_issuer_url`. In host mode that should be reachable from the VMs over the Multipass gateway IP.

## Destroy

Destroying this folder removes only the Dex container and its local files, while leaving the main cluster and any separate Nomad ACL auth-method config intact.

```bash
cd terraform/oidc
terraform destroy
```