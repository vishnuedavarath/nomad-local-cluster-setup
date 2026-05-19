# =============================================================================
# Nomad Local Cluster - Root Configuration
# =============================================================================
# This composes all modules to create a full Nomad cluster on Multipass VMs.
#
# Usage:
#   Phase 1: terraform apply -target=module.instances -target=module.cluster
#   Phase 2: terraform apply  (enables all Nomad-dependent modules)
# =============================================================================

provider "multipass" {}

# --------------------------------------------------------------------------- #
# Phase 1: Infrastructure (VMs + Cluster Bootstrap)                            #
# --------------------------------------------------------------------------- #

module "instances" {
  source = "../../modules/multipass-instances"

  server_count       = var.server_count
  client_count       = var.client_count
  server_name_prefix = var.server_name_prefix
  client_name_prefix = var.client_name_prefix
  vm_image           = var.vm_image
  server_cpus        = var.server_cpus
  server_memory      = var.server_memory
  server_disk        = var.server_disk
  client_cpus        = var.client_cpus
  client_memory      = var.client_memory
  client_disk        = var.client_disk
}

module "cluster" {
  source = "../../modules/nomad-cluster"

  server_names = module.instances.server_names
  client_names = module.instances.client_names
  server_ips   = module.instances.server_ips

  datacenter                    = var.datacenter
  nomad_edition                 = var.nomad_edition
  nomad_version                 = var.nomad_version
  nomad_enterprise_license      = var.nomad_enterprise_license
  nomad_enterprise_license_file = var.nomad_enterprise_license_file
  nomad_license_path_on_vm      = var.nomad_license_path_on_vm
  enable_acl                    = var.enable_acl
  enable_raw_exec               = var.enable_raw_exec
  enable_docker_volumes         = var.enable_docker_volumes
  install_docker                = var.install_docker
  vm_ready_delay                = var.vm_ready_delay
  cluster_stabilize_delay       = var.cluster_stabilize_delay
}

# --------------------------------------------------------------------------- #
# Nomad Provider (available after Phase 1)                                     #
# --------------------------------------------------------------------------- #
# Read bootstrap token directly from file on disk (written by Phase 1).
# This avoids stale state issues with data.local_file inside the module.

locals {
  acl_bootstrap_file = "${path.module}/../../modules/nomad-cluster/.nomad_acl_bootstrap.json"
  acl_bootstrap_token = var.enable_nomad_setup && var.enable_acl ? (
    fileexists(local.acl_bootstrap_file) ?
    try(jsondecode(file(local.acl_bootstrap_file)).SecretID, null) : null
  ) : null
}

provider "nomad" {
  address   = var.enable_nomad_setup ? module.cluster.nomad_address : "http://localhost:4646"
  secret_id = local.acl_bootstrap_token
}

# --------------------------------------------------------------------------- #
# Phase 2: Nomad Configuration (requires running cluster)                      #
# --------------------------------------------------------------------------- #

# --- ACL Policies & Tokens ---
module "acl" {
  count  = var.enable_nomad_setup && var.enable_acl ? 1 : 0
  source = "../../modules/nomad-acl"

  custom_policies = var.custom_acl_policies

  depends_on = [module.cluster]
}

# --- Namespaces ---
module "namespaces" {
  count  = var.enable_nomad_setup ? 1 : 0
  source = "../../modules/nomad-namespaces"

  namespaces = var.namespaces

  depends_on = [module.cluster]
}

# --- Host Volumes ---
module "volumes" {
  count  = var.enable_nomad_setup && var.enable_host_volumes ? 1 : 0
  source = "../../modules/nomad-volumes"

  client_names = module.instances.client_names
  host_volumes = var.host_volumes

  depends_on = [module.cluster]
}

# --- Secrets (Nomad Variables) ---
module "secrets" {
  count  = var.enable_nomad_setup && length(var.nomad_secrets) > 0 ? 1 : 0
  source = "../../modules/nomad-secrets"

  secrets = var.nomad_secrets

  depends_on = [module.namespaces]
}

# --- Jobs ---
module "jobs" {
  count  = var.enable_nomad_setup && var.enable_jobs ? 1 : 0
  source = "../../modules/nomad-jobs"

  jobs           = var.jobs
  templated_jobs = var.templated_jobs

  depends_on = [module.namespaces, module.volumes]
}

# --- Autoscaler ---
module "autoscaler" {
  count  = var.enable_nomad_setup && var.enable_autoscaler ? 1 : 0
  source = "../../modules/nomad-autoscaler"

  nomad_address      = module.cluster.nomad_address
  nomad_token        = var.enable_acl && length(module.acl) > 0 ? module.acl[0].ops_token : ""
  client_names       = module.instances.client_names
  namespace          = var.autoscaler_namespace
  datacenter         = var.datacenter
  autoscaler_version = var.autoscaler_version
  use_local_binary   = var.autoscaler_use_local_binary
  local_binary_path  = var.autoscaler_local_binary_path
  job_template_path  = var.autoscaler_job_template_path

  depends_on = [module.acl, module.namespaces]
}

# --- OIDC (Dex) ---
module "oidc" {
  count  = var.enable_nomad_setup && var.enable_oidc ? 1 : 0
  source = "../../modules/nomad-oidc"

  nomad_address            = module.cluster.nomad_address
  client_names             = module.instances.client_names
  client_ips               = module.instances.client_ips
  identity_client_index    = var.oidc_identity_client_index
  dex_runtime              = var.oidc_dex_runtime
  host_access_ip           = var.oidc_host_access_ip
  dex_image                = var.oidc_dex_image
  dex_container_name       = var.oidc_dex_container_name
  dex_http_port            = var.oidc_dex_http_port
  dex_client_id            = var.oidc_dex_client_id
  oidc_admin_email         = var.oidc_admin_email
  oidc_admin_username      = var.oidc_admin_username
  oidc_admin_password_hash = var.oidc_admin_password_hash
  additional_redirect_uris = var.oidc_additional_redirect_uris

  # Auth method configuration
  create_auth_method        = var.oidc_create_auth_method
  auth_method_name          = var.oidc_auth_method_name
  auth_method_max_token_ttl = var.oidc_auth_method_max_token_ttl
  make_default_auth_method  = var.oidc_make_default_auth_method
  binding_rules             = var.oidc_binding_rules

  depends_on = [module.acl, module.cluster]
}

# --------------------------------------------------------------------------- #
# Shell Environment: Update ~/.zshrc with NOMAD_ADDR and NOMAD_TOKEN           #
# --------------------------------------------------------------------------- #

resource "null_resource" "update_zshrc" {
  count = var.update_shell_env ? 1 : 0

  triggers = {
    nomad_address = module.cluster.nomad_address
    nomad_token   = var.enable_acl ? (length(module.acl) > 0 ? module.acl[0].admin_token : module.cluster.acl_bootstrap_token) : ""
    acl_enabled   = var.enable_acl
  }

  provisioner "local-exec" {
    interpreter = ["/bin/zsh", "-c"]
    command     = <<-EOT
      set -euo pipefail
      ZSHRC="$HOME/.zshrc"
      BEGIN_MARKER="# >>> nomad-local-cluster >>>"
      END_MARKER="# <<< nomad-local-cluster <<<"

      # Remove existing block if present
      if grep -q "$BEGIN_MARKER" "$ZSHRC" 2>/dev/null; then
        sed -i '' "/$BEGIN_MARKER/,/$END_MARKER/d" "$ZSHRC"
      fi

      # Build new block
      {
        echo "$BEGIN_MARKER"
        echo "export NOMAD_ADDR=\"${module.cluster.nomad_address}\""
        %{if var.enable_acl~}
        echo "export NOMAD_TOKEN=\"${length(module.acl) > 0 ? module.acl[0].admin_token : module.cluster.acl_bootstrap_token}\""
        %{endif~}
        echo "$END_MARKER"
      } >> "$ZSHRC"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/zsh", "-c"]
    command     = <<-EOT
      set -euo pipefail
      ZSHRC="$HOME/.zshrc"
      BEGIN_MARKER="# >>> nomad-local-cluster >>>"
      END_MARKER="# <<< nomad-local-cluster <<<"
      if grep -q "$BEGIN_MARKER" "$ZSHRC" 2>/dev/null; then
        sed -i '' "/$BEGIN_MARKER/,/$END_MARKER/d" "$ZSHRC"
      fi
    EOT
  }

  depends_on = [module.cluster, module.acl]
}
