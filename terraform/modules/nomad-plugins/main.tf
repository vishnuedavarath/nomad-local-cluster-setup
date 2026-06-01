# Module: nomad-plugins
# Prepares plugin infrastructure on client VMs:
# - CSI plugins: mount directories created on clients (jobs deployed via CLI)
# - Device plugins: binaries installed on client VMs
# - Driver plugins: binaries installed on client VMs

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# --------------------------------------------------------------------------- #
# Locals                                                                       #
# --------------------------------------------------------------------------- #

locals {
  # Collect all mount_dirs from all CSI plugins
  csi_mount_dirs = distinct(flatten([for k, v in var.csi_plugins : v.mount_dirs]))

  # Merge device + driver plugins for VM installation
  all_vm_plugins = merge(
    { for k, v in var.device_plugins : k => merge(v, { type = "device" }) },
    { for k, v in var.driver_plugins : k => merge(v, { type = "driver" }) },
  )
}

# =========================================================================== #
# Prepare CSI mount directories on client VMs                                  #
# =========================================================================== #

resource "null_resource" "csi_mount_dirs" {
  count = length(var.client_names) > 0 && length(local.csi_mount_dirs) > 0 ? length(var.client_names) : 0

  triggers = {
    client_name = var.client_names[count.index]
    mount_dirs  = jsonencode(local.csi_mount_dirs)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.client_names[count.index]}"
%{for dir in local.csi_mount_dirs~}
      multipass exec $VM -- sudo mkdir -p "${dir}"
%{endfor~}
    EOT
  }
}

# =========================================================================== #
# CSI Plugins — deployed via CLI (scripts/deploy-csi-plugins.sh)               #
# =========================================================================== #
# CSI plugin jobs live in nomad-jobs/csi/ and are deployed using the Nomad CLI.
# Terraform only prepares mount directories on client VMs (above).

# =========================================================================== #
# Device & Driver Plugins (installed as binaries on client VMs)                #
# =========================================================================== #

resource "null_resource" "vm_plugins" {
  count = length(var.client_names) > 0 && length(local.all_vm_plugins) > 0 ? length(var.client_names) : 0

  triggers = {
    client_name = var.client_names[count.index]
    plugins     = jsonencode(local.all_vm_plugins)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.client_names[count.index]}"

      # Ensure plugin directory exists
      multipass exec $VM -- sudo mkdir -p /opt/nomad/plugins

%{for name, plugin in local.all_vm_plugins~}
      # Install plugin: ${name} (${plugin.type})
      echo "Installing ${plugin.type} plugin '${name}' on $VM..."
      multipass exec $VM -- sudo bash -c '
        set -euo pipefail
        PLUGIN_DIR="${plugin.plugin_dir}"
        BINARY_NAME="${plugin.binary_name != "" ? plugin.binary_name : name}"
        DOWNLOAD_URL="${plugin.download_url}"

        mkdir -p "$PLUGIN_DIR"
        TMP_FILE=$(mktemp)

        # Download plugin
        wget -q -O "$TMP_FILE" "$DOWNLOAD_URL"

        # Handle zip vs raw binary
        if file "$TMP_FILE" | grep -q "Zip archive"; then
          apt-get install -y -qq unzip > /dev/null 2>&1 || true
          unzip -o -q "$TMP_FILE" -d "$PLUGIN_DIR"
          rm -f "$TMP_FILE"
          # Make all extracted files executable
          find "$PLUGIN_DIR" -type f -newer "$PLUGIN_DIR" -exec chmod +x {} \;
        else
          mv "$TMP_FILE" "$PLUGIN_DIR/$BINARY_NAME"
          chmod +x "$PLUGIN_DIR/$BINARY_NAME"
        fi
      '

%{endfor~}

      # Write plugin config to Nomad
      cat <<'EOF' > /tmp/$${VM}_plugins.hcl
plugin_dir = "/opt/nomad/plugins"

%{for name, plugin in local.all_vm_plugins~}
%{if plugin.config_hcl != ""~}
plugin "${plugin.binary_name != "" ? plugin.binary_name : name}" {
  ${plugin.config_hcl}
}
%{endif~}
%{endfor~}
EOF

      multipass transfer /tmp/$${VM}_plugins.hcl $VM:/tmp/plugins.hcl
      multipass exec $VM -- sudo mv /tmp/plugins.hcl /etc/nomad.d/plugins.hcl
      multipass exec $VM -- sudo systemctl restart nomad
      rm -f /tmp/$${VM}_plugins.hcl
    EOT
  }
}
