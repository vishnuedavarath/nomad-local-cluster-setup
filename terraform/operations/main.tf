terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Nomad ACL token (management token for creating resources)
# Set via: export TF_VAR_nomad_token="<token>"
variable "nomad_token" {
  description = "Nomad ACL token (management token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "update_zshrc" {
  description = "When true, write NOMAD_ADDR and NOMAD_TOKEN to ~/.zshrc after apply"
  type        = bool
  default     = false
}

# Read the cluster state to get the Nomad address.
data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  nomad_address = data.terraform_remote_state.cluster.outputs.nomad_ui_url
  nomad_token   = try(data.terraform_remote_state.cluster.outputs.acl_bootstrap_token, "")
}

provider "nomad" {
  address   = local.nomad_address
  secret_id = var.nomad_token != "" ? var.nomad_token : (local.nomad_token != "" ? local.nomad_token : null)
}

resource "null_resource" "update_zshrc" {
  count = var.update_zshrc ? 1 : 0

  triggers = {
    nomad_addr  = local.nomad_address
    admin_token = nomad_acl_token.admin.secret_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      RC_FILE="$HOME/.zshrc"
      TMP_FILE="$(mktemp)"

      if [ -f "$RC_FILE" ]; then
        awk '
          BEGIN { skip = 0 }
          /^# >>> nomad-local-cluster >>>$/ { skip = 1; next }
          /^# <<< nomad-local-cluster <<</ { skip = 0; next }
          skip == 0 { print }
        ' "$RC_FILE" > "$TMP_FILE"
      fi

      cat >> "$TMP_FILE" <<'EOF'
# >>> nomad-local-cluster >>>
export NOMAD_ADDR="${self.triggers.nomad_addr}"
export NOMAD_TOKEN="${self.triggers.admin_token}"
# <<< nomad-local-cluster <<<
EOF

      mv "$TMP_FILE" "$RC_FILE"
    EOT
  }

  depends_on = [nomad_acl_token.admin]
}
