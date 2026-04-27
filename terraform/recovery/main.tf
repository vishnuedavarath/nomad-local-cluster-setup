# Cluster Recovery - Use this to bring up stopped VMs and restart services
# Run: terraform apply

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Read cluster state to get VM names
data "terraform_remote_state" "cluster" {
  backend = "local"
  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

# Read operations state to get ACL tokens
data "terraform_remote_state" "operations" {
  backend = "local"
  config = {
    path = "${path.module}/../operations/terraform.tfstate"
  }
}

locals {
  server_names = data.terraform_remote_state.cluster.outputs.server_names
  client_names = data.terraform_remote_state.cluster.outputs.client_names
  all_vms      = concat(local.server_names, local.client_names)
  # Use provided token, or fall back to admin token from operations state
  nomad_token = var.nomad_token != "" ? var.nomad_token : try(data.terraform_remote_state.operations.outputs.acl_tokens.admin.secret_id, "")
}

# Start all VMs
resource "null_resource" "start_vms" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "multipass start --all"
  }
}

# Wait for VMs to be ready
resource "null_resource" "wait_for_vms" {
  depends_on = [null_resource.start_vms]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Restart services on server nodes
resource "null_resource" "restart_servers" {
  count      = length(local.server_names)
  depends_on = [null_resource.wait_for_vms]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Restarting services on ${local.server_names[count.index]}..."
      multipass exec ${local.server_names[count.index]} -- sudo systemctl restart consul
      sleep 2
      multipass exec ${local.server_names[count.index]} -- sudo systemctl restart nomad
    EOT
  }
}

# Wait for servers to stabilize before starting clients
resource "null_resource" "wait_for_servers" {
  depends_on = [null_resource.restart_servers]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Restart services on client nodes
resource "null_resource" "restart_clients" {
  count      = length(local.client_names)
  depends_on = [null_resource.wait_for_servers]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Restarting services on ${local.client_names[count.index]}..."
      multipass exec ${local.client_names[count.index]} -- sudo systemctl restart consul
      sleep 2
      multipass exec ${local.client_names[count.index]} -- sudo systemctl restart nomad
    EOT
  }
}

# Verify cluster health
resource "null_resource" "verify_cluster" {
  depends_on = [null_resource.restart_clients]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo ""
      echo "=== Cluster Recovery Complete ==="
      echo ""
      echo "VM Status:"
      multipass list | grep nomad
      echo ""
      echo "Waiting for cluster to stabilize..."
      sleep 5
      
      # Get first server IP
      SERVER_IP=$(multipass info ${local.server_names[0]} --format json | jq -r '.info."${local.server_names[0]}".ipv4[0]')
      
      echo ""
      echo "Nomad Server Members:"
      NOMAD_ADDR="http://$SERVER_IP:4646" NOMAD_TOKEN="${local.nomad_token}" nomad server members 2>/dev/null || echo "(waiting for leader election...)"
      
      echo ""
      echo "Nomad Node Status:"
      NOMAD_ADDR="http://$SERVER_IP:4646" NOMAD_TOKEN="${local.nomad_token}" nomad node status 2>/dev/null || echo "(nodes joining...)"
    EOT
  }
}

variable "nomad_token" {
  description = "Nomad ACL token for verification (optional - falls back to admin token from operations state)"
  type        = string
  default     = ""
  sensitive   = true
}

output "server_names" {
  value = local.server_names
}

output "client_names" {
  value = local.client_names
}

output "recovery_status" {
  value = "Cluster recovery completed. Run 'multipass list' to verify VM status."
}
