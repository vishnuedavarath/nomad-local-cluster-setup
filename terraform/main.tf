terraform {
  required_version = ">= 1.5.0"

  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
  }
}

provider "multipass" {}

# Generate random suffixes for server names
resource "random_id" "server_suffix" {
  count       = var.server_count
  byte_length = 3

  # Keepers ensure the random ID only changes if these values change
  keepers = {
    index = count.index
  }
}

# Generate random suffixes for client names
resource "random_id" "client_suffix" {
  count       = var.client_count
  byte_length = 3

  keepers = {
    index = count.index
  }
}

locals {
  nomad_enterprise_enabled = var.nomad_edition == "enterprise"
  nomad_release_version    = local.nomad_enterprise_enabled ? "${var.nomad_version}+ent" : var.nomad_version
  nomad_license_source     = trimspace(var.nomad_enterprise_license_file) != "" ? pathexpand(var.nomad_enterprise_license_file) : ""
  nomad_license_content    = trimspace(var.nomad_enterprise_license) != "" ? trimspace(var.nomad_enterprise_license) : (local.nomad_license_source != "" ? trimspace(file(local.nomad_license_source)) : "")
  server_names             = [for i, id in random_id.server_suffix : "nomad-server-${id.hex}"]
  client_names             = [for i, id in random_id.client_suffix : "nomad-client-${id.hex}"]
}

# --- STEP 1: LAUNCH SERVER VMS ---
resource "multipass_instance" "nomad_servers" {
  count = var.server_count

  name   = local.server_names[count.index]
  image  = var.vm_image
  cpus   = var.server_cpus
  memory = var.server_memory
  disk   = var.server_disk
}

# --- STEP 2: LAUNCH CLIENT VMS ---
resource "multipass_instance" "nomad_clients" {
  count = var.client_count

  name   = local.client_names[count.index]
  image  = var.vm_image
  cpus   = var.client_cpus
  memory = var.client_memory
  disk   = var.client_disk
}

# --- STEP 3: BUILD RETRY JOIN STRING FROM SERVER IPS ---
locals {
  server_ips        = [for s in multipass_instance.nomad_servers : s.ipv4]
  retry_join_string = jsonencode(local.server_ips)
}

# --- WAIT FOR VMS TO BE FULLY READY ---
resource "time_sleep" "wait_for_vms" {
  depends_on = [
    multipass_instance.nomad_servers,
    multipass_instance.nomad_clients
  ]

  create_duration = "30s"
}

# --- STEP 4: INSTALL NOMAD + CONSUL ON ALL NODES ---
resource "null_resource" "install_nomad_servers" {
  count = var.server_count

  depends_on = [time_sleep.wait_for_vms]

  triggers = {
    nomad_edition = var.nomad_edition
    nomad_version = local.nomad_release_version
    instance_name = local.server_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for cloud-init to complete
      multipass exec ${local.server_names[count.index]} -- cloud-init status --wait || true
      multipass exec ${local.server_names[count.index]} -- sudo killall apt apt-get dpkg || true
      multipass exec ${local.server_names[count.index]} -- sudo dpkg --configure -a
      multipass exec ${local.server_names[count.index]} -- sudo apt-get update
      multipass exec ${local.server_names[count.index]} -- sudo apt-get install wget unzip gpg coreutils -y
      multipass exec ${local.server_names[count.index]} -- bash -c 'wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes'
      multipass exec ${local.server_names[count.index]} -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'
      multipass exec ${local.server_names[count.index]} -- sudo apt-get update
      multipass exec ${local.server_names[count.index]} -- sudo apt-get install nomad consul -y
      multipass exec ${local.server_names[count.index]} -- sudo systemctl stop nomad || true
      multipass exec ${local.server_names[count.index]} -- bash -lc '
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

resource "null_resource" "install_nomad_clients" {
  count = var.client_count

  depends_on = [time_sleep.wait_for_vms]

  triggers = {
    nomad_edition = var.nomad_edition
    nomad_version = local.nomad_release_version
    instance_name = local.client_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for cloud-init to complete
      multipass exec ${local.client_names[count.index]} -- cloud-init status --wait || true
      multipass exec ${local.client_names[count.index]} -- sudo killall apt apt-get dpkg || true
      multipass exec ${local.client_names[count.index]} -- sudo dpkg --configure -a
      multipass exec ${local.client_names[count.index]} -- sudo apt-get update
      multipass exec ${local.client_names[count.index]} -- sudo apt-get install wget unzip gpg coreutils -y
      multipass exec ${local.client_names[count.index]} -- bash -c 'wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes'
      multipass exec ${local.client_names[count.index]} -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'
      multipass exec ${local.client_names[count.index]} -- sudo apt-get update
      multipass exec ${local.client_names[count.index]} -- sudo apt-get install nomad consul -y
      multipass exec ${local.client_names[count.index]} -- sudo systemctl stop nomad || true
      multipass exec ${local.client_names[count.index]} -- bash -lc '
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

# --- STEP 5: INSTALL DOCKER ON CLIENTS ---
resource "null_resource" "install_docker_clients" {
  count = var.client_count

  depends_on = [null_resource.install_nomad_clients]

  provisioner "local-exec" {
    command = <<-EOT
      multipass exec ${local.client_names[count.index]} -- sudo DEBIAN_FRONTEND=noninteractive apt-get install docker.io -yq
      multipass exec ${local.client_names[count.index]} -- sudo systemctl enable --now docker
      multipass exec ${local.client_names[count.index]} -- sudo usermod -aG docker ubuntu
    EOT
  }
}

# --- STEP 6: CONFIGURE NOMAD SERVERS (HA) ---
resource "null_resource" "configure_nomad_servers" {
  count = var.server_count

  depends_on = [null_resource.install_nomad_servers]

  triggers = {
    datacenter           = var.datacenter
    server_name          = local.server_names[count.index]
    nomad_edition        = var.nomad_edition
    nomad_version        = local.nomad_release_version
    nomad_license_path   = var.nomad_enterprise_license_path
    nomad_license_digest = local.nomad_enterprise_enabled ? sha256(local.nomad_license_content) : "oss"
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<'EOF' > /tmp/${local.server_names[count.index]}_nomad.hcl
datacenter = "${var.datacenter}"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = ${var.server_count}
%{if local.nomad_enterprise_enabled~}
  license_path     = "${var.nomad_enterprise_license_path}"
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
  cat <<'EOF' > /tmp/${local.server_names[count.index]}_license.hclic
${local.nomad_license_content}
EOF
  multipass transfer /tmp/${local.server_names[count.index]}_license.hclic ${local.server_names[count.index]}:/tmp/license.hclic
  multipass exec ${local.server_names[count.index]} -- sudo install -D -o root -g nomad -m 0640 /tmp/license.hclic ${var.nomad_enterprise_license_path}
  multipass exec ${local.server_names[count.index]} -- rm -f /tmp/license.hclic
%{endif~}
      multipass transfer /tmp/${local.server_names[count.index]}_nomad.hcl ${local.server_names[count.index]}:/tmp/nomad.hcl
      multipass exec ${local.server_names[count.index]} -- sudo mv /tmp/nomad.hcl /etc/nomad.d/nomad.hcl
      multipass exec ${local.server_names[count.index]} -- sudo systemctl restart nomad
    EOT
  }
}

# --- STEP 7: CONFIGURE CONSUL SERVERS ---
resource "null_resource" "configure_consul_servers" {
  count = var.server_count

  depends_on = [null_resource.install_nomad_servers]

  triggers = {
    datacenter  = var.datacenter
    server_name = local.server_names[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<'EOF' > /tmp/${local.server_names[count.index]}_consul.hcl
datacenter = "${var.datacenter}"
data_dir   = "/opt/consul/data"
bind_addr  = "0.0.0.0"
client_addr = "0.0.0.0"

server = true
bootstrap_expect = ${var.server_count}

retry_join = ${local.retry_join_string}

ui_config {
  enabled = true
}
EOF
      multipass transfer /tmp/${local.server_names[count.index]}_consul.hcl ${local.server_names[count.index]}:/tmp/consul.hcl
      multipass exec ${local.server_names[count.index]} -- sudo mkdir -p /opt/consul/data
      multipass exec ${local.server_names[count.index]} -- sudo chown -R consul:consul /opt/consul
      multipass exec ${local.server_names[count.index]} -- sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl
      multipass exec ${local.server_names[count.index]} -- sudo systemctl enable consul
      multipass exec ${local.server_names[count.index]} -- sudo systemctl restart consul
    EOT
  }
}

# --- STEP 8: CONFIGURE CONSUL CLIENTS ---
resource "null_resource" "configure_consul_clients" {
  count = var.client_count

  depends_on = [null_resource.install_nomad_clients]

  triggers = {
    datacenter    = var.datacenter
    client_name   = local.client_names[count.index]
    nomad_edition = var.nomad_edition
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<'EOF' > /tmp/${local.client_names[count.index]}_consul.hcl
datacenter = "${var.datacenter}"
data_dir   = "/opt/consul/data"
bind_addr  = "{{ GetInterfaceIP \"enp0s1\" }}"
client_addr = "0.0.0.0"

server = false

retry_join = ${local.retry_join_string}
EOF
      multipass transfer /tmp/${local.client_names[count.index]}_consul.hcl ${local.client_names[count.index]}:/tmp/consul.hcl
      multipass exec ${local.client_names[count.index]} -- sudo mkdir -p /opt/consul/data
      multipass exec ${local.client_names[count.index]} -- sudo chown -R consul:consul /opt/consul
      multipass exec ${local.client_names[count.index]} -- sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl
      multipass exec ${local.client_names[count.index]} -- sudo systemctl enable consul
      multipass exec ${local.client_names[count.index]} -- sudo systemctl restart consul
    EOT
  }
}

# --- STEP 9: CONFIGURE NOMAD CLIENTS ---
resource "null_resource" "configure_nomad_clients" {
  count = var.client_count

  depends_on = [
    null_resource.install_docker_clients,
    null_resource.configure_consul_clients
  ]

  triggers = {
    datacenter    = var.datacenter
    client_name   = local.client_names[count.index]
    nomad_edition = var.nomad_edition
    nomad_version = local.nomad_release_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<'EOF' > /tmp/${local.client_names[count.index]}_nomad.hcl
datacenter = "${var.datacenter}"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

plugin "raw_exec" {
  config {
    enabled = true
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
      enabled = true
    }
  }
}

%{if var.enable_acl~}
acl {
  enabled = true
}
%{endif~}
EOF
      multipass transfer /tmp/${local.client_names[count.index]}_nomad.hcl ${local.client_names[count.index]}:/tmp/nomad.hcl
      multipass exec ${local.client_names[count.index]} -- sudo mv /tmp/nomad.hcl /etc/nomad.d/nomad.hcl
      multipass exec ${local.client_names[count.index]} -- sudo systemctl restart nomad
    EOT
  }
}

# --- STEP 10: WAIT FOR NOMAD CLUSTER TO STABILIZE ---
resource "time_sleep" "wait_for_nomad_cluster" {
  depends_on = [
    null_resource.configure_nomad_servers,
    null_resource.configure_nomad_clients
  ]

  create_duration = "15s"
}

# --- STEP 11: BOOTSTRAP ACL (if enabled) ---
resource "null_resource" "bootstrap_acl" {
  count = var.enable_acl ? 1 : 0

  depends_on = [time_sleep.wait_for_nomad_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      # Bootstrap ACL on the server, then copy the result to the local module path.
      VM_BOOTSTRAP_FILE="/tmp/nomad_acl_bootstrap.json"
      HOST_BOOTSTRAP_FILE="${path.module}/.nomad_acl_bootstrap.json"

      # Ensure a readable local file exists even if bootstrap was already done.
      printf '{}\n' > "$HOST_BOOTSTRAP_FILE"

      multipass exec ${local.server_names[0]} -- bash -lc "nomad acl bootstrap -json > $VM_BOOTSTRAP_FILE" 2>/dev/null || true
      multipass transfer ${local.server_names[0]}:$VM_BOOTSTRAP_FILE "$HOST_BOOTSTRAP_FILE" 2>/dev/null || true
    EOT
  }
}

locals {
  acl_bootstrap_file  = "${path.module}/.nomad_acl_bootstrap.json"
  acl_bootstrap_json  = fileexists(local.acl_bootstrap_file) ? file(local.acl_bootstrap_file) : "{}"
  acl_bootstrap_token = var.enable_acl ? try(jsondecode(local.acl_bootstrap_json).SecretID, "Bootstrap failed or already done") : "ACL disabled"
}
