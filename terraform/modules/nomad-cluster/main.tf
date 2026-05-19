# Module: nomad-cluster
# Installs Nomad + Consul on existing VMs and configures the cluster.
# Completely decoupled from VM provisioning.

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# --------------------------------------------------------------------------- #
# Locals                                                                       #
# --------------------------------------------------------------------------- #

locals {
  nomad_enterprise_enabled = var.nomad_edition == "enterprise"
  nomad_release_version    = local.nomad_enterprise_enabled ? "${var.nomad_version}+ent" : var.nomad_version

  nomad_license_content = local.nomad_enterprise_enabled ? (
    trimspace(var.nomad_enterprise_license) != "" ? trimspace(var.nomad_enterprise_license) : (
      trimspace(var.nomad_enterprise_license_file) != "" && fileexists(pathexpand(var.nomad_enterprise_license_file)) ?
      trimspace(file(pathexpand(var.nomad_enterprise_license_file))) : ""
    )
  ) : ""

  retry_join_string = jsonencode(var.server_ips)
}

# --------------------------------------------------------------------------- #
# Wait for VMs to be fully ready (cloud-init)                                  #
# --------------------------------------------------------------------------- #

resource "time_sleep" "wait_for_vms" {
  create_duration = var.vm_ready_delay
}

# --------------------------------------------------------------------------- #
# Install Nomad + Consul on servers                                            #
# --------------------------------------------------------------------------- #

resource "null_resource" "install_servers" {
  count      = length(var.server_names)
  depends_on = [time_sleep.wait_for_vms]

  triggers = {
    nomad_edition = var.nomad_edition
    nomad_version = local.nomad_release_version
    instance_name = var.server_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      VM="${var.server_names[count.index]}"

      # Wait for cloud-init to complete
      multipass exec $VM -- cloud-init status --wait || true
      multipass exec $VM -- sudo dpkg --configure -a
      multipass exec $VM -- sudo apt-get update
      multipass exec $VM -- sudo apt-get install wget unzip gpg coreutils -y
      multipass exec $VM -- bash -c 'wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes'
      multipass exec $VM -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'
      multipass exec $VM -- sudo apt-get update
      multipass exec $VM -- sudo apt-get install nomad consul -y
      multipass exec $VM -- sudo systemctl stop nomad || true
      multipass exec $VM -- bash -lc '
        set -euo pipefail
        case "$(uname -m)" in
          aarch64|arm64) ARCH="arm64" ;;
          x86_64|amd64) ARCH="amd64" ;;
          *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
        esac
        NOMAD_VERSION="${local.nomad_release_version}"
        NOMAD_ZIP="nomad_${local.nomad_release_version}_linux_$${ARCH}.zip"
        wget -q -O /tmp/$NOMAD_ZIP "https://releases.hashicorp.com/nomad/$NOMAD_VERSION/$NOMAD_ZIP"
        unzip -oq /tmp/$NOMAD_ZIP -d /tmp/nomad-install
        sudo install -m 0755 /tmp/nomad-install/nomad /usr/bin/nomad
        rm -rf /tmp/nomad-install /tmp/$NOMAD_ZIP
      '
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Install Nomad + Consul on clients                                            #
# --------------------------------------------------------------------------- #

resource "null_resource" "install_clients" {
  count      = length(var.client_names)
  depends_on = [time_sleep.wait_for_vms]

  triggers = {
    nomad_edition = var.nomad_edition
    nomad_version = local.nomad_release_version
    instance_name = var.client_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      VM="${var.client_names[count.index]}"

      # Wait for cloud-init to complete
      multipass exec $VM -- cloud-init status --wait || true
      multipass exec $VM -- sudo dpkg --configure -a
      multipass exec $VM -- sudo apt-get update
      multipass exec $VM -- sudo apt-get install wget unzip gpg coreutils -y
      multipass exec $VM -- bash -c 'wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes'
      multipass exec $VM -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'
      multipass exec $VM -- sudo apt-get update
      multipass exec $VM -- sudo apt-get install nomad consul -y
      multipass exec $VM -- sudo systemctl stop nomad || true
      multipass exec $VM -- bash -lc '
        set -euo pipefail
        case "$(uname -m)" in
          aarch64|arm64) ARCH="arm64" ;;
          x86_64|amd64) ARCH="amd64" ;;
          *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
        esac
        NOMAD_VERSION="${local.nomad_release_version}"
        NOMAD_ZIP="nomad_${local.nomad_release_version}_linux_$${ARCH}.zip"
        wget -q -O /tmp/$NOMAD_ZIP "https://releases.hashicorp.com/nomad/$NOMAD_VERSION/$NOMAD_ZIP"
        unzip -oq /tmp/$NOMAD_ZIP -d /tmp/nomad-install
        sudo install -m 0755 /tmp/nomad-install/nomad /usr/bin/nomad
        rm -rf /tmp/nomad-install /tmp/$NOMAD_ZIP
      '
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Install Docker on clients                                                    #
# --------------------------------------------------------------------------- #

resource "null_resource" "install_docker" {
  count      = var.install_docker ? length(var.client_names) : 0
  depends_on = [null_resource.install_clients]

  triggers = {
    instance_name = var.client_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.client_names[count.index]}"
      multipass exec $VM -- sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq docker.io
      multipass exec $VM -- sudo systemctl enable --now docker
      multipass exec $VM -- sudo usermod -aG docker ubuntu
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Configure Consul servers                                                     #
# --------------------------------------------------------------------------- #

resource "null_resource" "configure_consul_servers" {
  count      = length(var.server_names)
  depends_on = [null_resource.install_servers]

  triggers = {
    datacenter  = var.datacenter
    server_name = var.server_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.server_names[count.index]}"

      cat <<'EOF' > /tmp/$${VM}_consul.hcl
datacenter  = "${var.datacenter}"
data_dir    = "/opt/consul/data"
bind_addr   = "0.0.0.0"
client_addr = "0.0.0.0"

server           = true
bootstrap_expect = ${length(var.server_names)}

retry_join = ${local.retry_join_string}

ui_config {
  enabled = true
}
EOF

      multipass transfer /tmp/$${VM}_consul.hcl $VM:/tmp/consul.hcl
      multipass exec $VM -- sudo mkdir -p /opt/consul/data
      multipass exec $VM -- sudo chown -R consul:consul /opt/consul
      multipass exec $VM -- sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl
      multipass exec $VM -- sudo systemctl enable consul
      multipass exec $VM -- sudo systemctl restart consul
      rm -f /tmp/$${VM}_consul.hcl
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Configure Consul clients                                                     #
# --------------------------------------------------------------------------- #

resource "null_resource" "configure_consul_clients" {
  count      = length(var.client_names)
  depends_on = [null_resource.install_clients]

  triggers = {
    datacenter  = var.datacenter
    client_name = var.client_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.client_names[count.index]}"

      cat <<'EOF' > /tmp/$${VM}_consul.hcl
datacenter  = "${var.datacenter}"
data_dir    = "/opt/consul/data"
bind_addr   = "{{ GetInterfaceIP \"enp0s1\" }}"
client_addr = "0.0.0.0"

server = false

retry_join = ${local.retry_join_string}
EOF

      multipass transfer /tmp/$${VM}_consul.hcl $VM:/tmp/consul.hcl
      multipass exec $VM -- sudo mkdir -p /opt/consul/data
      multipass exec $VM -- sudo chown -R consul:consul /opt/consul
      multipass exec $VM -- sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl
      multipass exec $VM -- sudo systemctl enable consul
      multipass exec $VM -- sudo systemctl restart consul
      rm -f /tmp/$${VM}_consul.hcl
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Configure Nomad servers                                                      #
# --------------------------------------------------------------------------- #

resource "null_resource" "configure_nomad_servers" {
  count      = length(var.server_names)
  depends_on = [null_resource.configure_consul_servers]

  triggers = {
    datacenter           = var.datacenter
    server_name          = var.server_names[count.index]
    nomad_edition        = var.nomad_edition
    nomad_version        = local.nomad_release_version
    nomad_license_digest = local.nomad_enterprise_enabled ? sha256(local.nomad_license_content) : "oss"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.server_names[count.index]}"

      cat <<'EOF' > /tmp/$${VM}_nomad.hcl
datacenter = "${var.datacenter}"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = ${length(var.server_names)}
%{if local.nomad_enterprise_enabled~}
  license_path     = "${var.nomad_license_path_on_vm}"
%{endif~}
  server_join {
    retry_join = ${local.retry_join_string}
  }
}

%{if var.enable_acl~}
acl {
  enabled = true
}
%{endif~}
EOF

%{if local.nomad_enterprise_enabled~}
      cat <<'EOF' > /tmp/$${VM}_license.hclic
${local.nomad_license_content}
EOF
      multipass transfer /tmp/$${VM}_license.hclic $VM:/tmp/license.hclic
      multipass exec $VM -- sudo install -D -o root -g nomad -m 0640 /tmp/license.hclic ${var.nomad_license_path_on_vm}
      multipass exec $VM -- rm -f /tmp/license.hclic
      rm -f /tmp/$${VM}_license.hclic
%{endif~}

      multipass transfer /tmp/$${VM}_nomad.hcl $VM:/tmp/nomad.hcl
      multipass exec $VM -- sudo mv /tmp/nomad.hcl /etc/nomad.d/nomad.hcl
      multipass exec $VM -- sudo systemctl restart nomad
      rm -f /tmp/$${VM}_nomad.hcl
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Configure Nomad clients                                                      #
# --------------------------------------------------------------------------- #

resource "null_resource" "configure_nomad_clients" {
  count = length(var.client_names)

  depends_on = [
    null_resource.install_docker,
    null_resource.configure_consul_clients,
  ]

  triggers = {
    datacenter    = var.datacenter
    client_name   = var.client_names[count.index]
    nomad_edition = var.nomad_edition
    nomad_version = local.nomad_release_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.client_names[count.index]}"

      cat <<'EOF' > /tmp/$${VM}_nomad.hcl
datacenter = "${var.datacenter}"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

plugin "raw_exec" {
  config {
    enabled = ${var.enable_raw_exec}
  }
}

client {
  enabled = true
  servers = ${local.retry_join_string}
}

consul {
  address = "127.0.0.1:8500"
}

plugin "docker" {
  config {
    volumes {
      enabled = ${var.enable_docker_volumes}
    }
  }
}

%{if var.enable_acl~}
acl {
  enabled = true
}
%{endif~}
EOF

      multipass transfer /tmp/$${VM}_nomad.hcl $VM:/tmp/nomad.hcl
      multipass exec $VM -- sudo mv /tmp/nomad.hcl /etc/nomad.d/nomad.hcl
      multipass exec $VM -- sudo systemctl restart nomad
      rm -f /tmp/$${VM}_nomad.hcl
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Wait for cluster to stabilize                                                #
# --------------------------------------------------------------------------- #

resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    null_resource.configure_nomad_servers,
    null_resource.configure_nomad_clients,
  ]

  create_duration = var.cluster_stabilize_delay
}

# --------------------------------------------------------------------------- #
# ACL Bootstrap                                                                #
# --------------------------------------------------------------------------- #

resource "null_resource" "bootstrap_acl" {
  count      = var.enable_acl ? 1 : 0
  depends_on = [time_sleep.wait_for_cluster]

  triggers = {
    server_name    = var.server_names[0]
    bootstrap_file = "${path.module}/.nomad_acl_bootstrap.json"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      VM="${var.server_names[0]}"
      VM_FILE="/tmp/nomad_acl_bootstrap.json"
      HOST_FILE="${path.module}/.nomad_acl_bootstrap.json"

      # Skip if already bootstrapped successfully
      if [ -f "$HOST_FILE" ] && grep -q "SecretID" "$HOST_FILE" 2>/dev/null; then
        echo "ACL already bootstrapped, skipping."
        exit 0
      fi

      printf '{}\n' > "$HOST_FILE"

      # Retry bootstrap (cluster may still be electing a leader)
      for i in 1 2 3 4 5; do
        if multipass exec $VM -- bash -lc "nomad acl bootstrap -json" > "$HOST_FILE" 2>/dev/null; then
          if grep -q "SecretID" "$HOST_FILE" 2>/dev/null; then
            echo "ACL bootstrap successful on attempt $i."
            exit 0
          fi
        fi
        echo "Bootstrap attempt $i failed, retrying in 5s..."
        sleep 5
      done

      echo "WARNING: ACL bootstrap failed after 5 attempts. May already be bootstrapped." >&2
      printf '{}\n' > "$HOST_FILE"
    EOT
  }
}

# Read the bootstrap token from the file written by the provisioner above.
# IMPORTANT: On the very first apply this will be "bootstrap-pending" because
# file() evaluates at plan time. A second apply (or refresh) is required to
# pick up the token. This is an inherent Terraform limitation with provisioners.
data "local_file" "acl_bootstrap" {
  count    = var.enable_acl ? 1 : 0
  filename = "${path.module}/.nomad_acl_bootstrap.json"

  depends_on = [null_resource.bootstrap_acl]
}
