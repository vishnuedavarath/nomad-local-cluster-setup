# Module: multipass-instances
# Manages the lifecycle of Multipass VMs (launch/destroy only).
# No Nomad or Consul configuration happens here.

terraform {
  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# --------------------------------------------------------------------------- #
# Random suffixes for unique VM names                                          #
# --------------------------------------------------------------------------- #

resource "random_id" "server_suffix" {
  count       = var.server_count
  byte_length = 3

  keepers = {
    index = count.index
  }
}

resource "random_id" "client_suffix" {
  count       = var.client_count
  byte_length = 3

  keepers = {
    index = count.index
  }
}

locals {
  server_names = [for i, id in random_id.server_suffix : "${var.server_name_prefix}-${id.hex}"]
  client_names = [for i, id in random_id.client_suffix : "${var.client_name_prefix}-${id.hex}"]

  # Detect if image is a remote URL that needs pre-downloading
  is_remote_image = can(regex("^https?://", var.vm_image))
  image_filename  = local.is_remote_image ? basename(var.vm_image) : ""
  local_image_dir = "${path.module}/.image-cache"
  local_image_path = local.is_remote_image ? "${local.local_image_dir}/${local.image_filename}" : ""
  effective_image  = local.is_remote_image ? "file://${local.local_image_path}" : var.vm_image
}

# --------------------------------------------------------------------------- #
# Pre-download remote image (avoids 6 parallel downloads crashing multipassd)  #
# --------------------------------------------------------------------------- #

resource "null_resource" "download_image" {
  count = local.is_remote_image ? 1 : 0

  triggers = {
    image_url = var.vm_image
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${local.local_image_dir}"
      if [ ! -f "${local.local_image_path}" ]; then
        echo "Downloading VM image: ${var.vm_image}"
        curl -fSL --progress-bar -o "${local.local_image_path}.tmp" "${var.vm_image}"
        mv "${local.local_image_path}.tmp" "${local.local_image_path}"
      else
        echo "Image already cached: ${local.local_image_path}"
      fi
    EOT
  }
}

# --------------------------------------------------------------------------- #
# Server VMs                                                                   #
# --------------------------------------------------------------------------- #

resource "multipass_instance" "servers" {
  count = var.server_count

  name   = local.server_names[count.index]
  image  = local.effective_image
  cpus   = var.server_cpus
  memory = var.server_memory
  disk   = var.server_disk

  depends_on = [null_resource.download_image]
}

# --------------------------------------------------------------------------- #
# Client VMs                                                                   #
# --------------------------------------------------------------------------- #

resource "multipass_instance" "clients" {
  count = var.client_count

  name   = local.client_names[count.index]
  image  = local.effective_image
  cpus   = var.client_cpus
  memory = var.client_memory
  disk   = var.client_disk

  depends_on = [null_resource.download_image]
}
