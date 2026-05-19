# Module: nomad-volumes
# Sets up host volumes on Nomad client VMs.

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "host_volumes" {
  count = length(var.client_names)

  triggers = {
    client_name = var.client_names[count.index]
    volumes     = jsonencode(var.host_volumes)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.client_names[count.index]}"

      # Create volume directories
%{for name, vol in var.host_volumes~}
      multipass exec $VM -- sudo mkdir -p "${vol.path}"
      multipass exec $VM -- sudo chmod ${vol.permissions} "${vol.path}"
%{endfor~}

      # Generate host_volume HCL config
      cat <<'EOF' > /tmp/$${VM}_host_volumes.hcl
client {
%{for name, vol in var.host_volumes~}
  host_volume "${name}" {
    path      = "${vol.path}"
    read_only = ${vol.read_only}
  }
%{endfor~}
}
EOF

      multipass transfer /tmp/$${VM}_host_volumes.hcl $VM:/tmp/host-volumes.hcl
      multipass exec $VM -- sudo mv /tmp/host-volumes.hcl /etc/nomad.d/host-volumes.hcl
      multipass exec $VM -- sudo systemctl restart nomad
      rm -f /tmp/$${VM}_host_volumes.hcl
    EOT
  }
}
