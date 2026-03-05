# Host Volumes for Persistent Storage
# These are simpler than CSI for local clusters

# Register host volumes on client nodes
# Note: Host volumes must be configured in the Nomad client config
# This null_resource sets them up on each client

# Setup host volumes - runs once per client, idempotent
resource "null_resource" "setup_host_volumes" {
  count = length(data.terraform_remote_state.cluster.outputs.client_names)

  # Only trigger on first run or if client changes
  triggers = {
    client_name = data.terraform_remote_state.cluster.outputs.client_names[count.index]
    version     = "1" # Bump this to force re-run
  }

  provisioner "local-exec" {
    command = <<-EOT
      CLIENT="${data.terraform_remote_state.cluster.outputs.client_names[count.index]}"
      
      # Single multipass exec with all commands batched
      multipass exec $CLIENT -- bash -c '
        # Create directories
        sudo mkdir -p /opt/nomad/volumes/{data,secrets,logs}
        sudo chmod 777 /opt/nomad/volumes/data
        sudo chmod 700 /opt/nomad/volumes/secrets
        sudo chmod 755 /opt/nomad/volumes/logs
        
        # Check if host_volume config already exists
        if ! grep -q "host_volume \"data\"" /etc/nomad.d/nomad.hcl 2>/dev/null; then
          sudo tee -a /etc/nomad.d/nomad.hcl > /dev/null <<EOF

# Host volumes for persistent storage
client {
  host_volume "data" {
    path      = "/opt/nomad/volumes/data"
    read_only = false
  }
  host_volume "secrets" {
    path      = "/opt/nomad/volumes/secrets"
    read_only = false
  }
  host_volume "logs" {
    path      = "/opt/nomad/volumes/logs"
    read_only = false
  }
}
EOF
          sudo systemctl restart nomad
          echo "Configured host volumes on $HOSTNAME"
        else
          echo "Host volumes already configured on $HOSTNAME"
        fi
      '
    EOT
  }
}

# Wait for clients to rejoin (reduced from 15s)
resource "null_resource" "wait_for_clients" {
  depends_on = [null_resource.setup_host_volumes]

  provisioner "local-exec" {
    command = "sleep 5"
  }
}

# Example job that uses host volumes
resource "nomad_job" "volume_demo" {
  depends_on = [null_resource.wait_for_clients]

  jobspec = <<-EOT
    job "volume-demo" {
      datacenters = ["local-dc"]
      namespace   = "development"
      type        = "service"

      group "app" {
        count = 1

        # Mount the host volumes
        volume "data" {
          type      = "host"
          source    = "data"
          read_only = false
        }

        volume "secrets" {
          type      = "host"
          source    = "secrets"
          read_only = false
        }

        task "writer" {
          driver = "docker"

          config {
            image   = "alpine:latest"
            command = "/bin/sh"
            args    = ["-c", "while true; do echo $(date) >> /data/log.txt; sleep 10; done"]
          }

          # Mount volumes into the container
          volume_mount {
            volume      = "data"
            destination = "/data"
          }

          volume_mount {
            volume      = "secrets"
            destination = "/app/secrets"  # Avoid /secrets - used by Nomad
            read_only   = true
          }

          resources {
            cpu    = 50
            memory = 32
          }
        }
      }
    }
  EOT
}

output "host_volumes" {
  description = "Available host volumes"
  value = {
    data = {
      path        = "/opt/nomad/volumes/data"
      description = "General persistent data"
    }
    secrets = {
      path        = "/opt/nomad/volumes/secrets"
      description = "Sensitive data (restricted permissions)"
    }
    logs = {
      path        = "/opt/nomad/volumes/logs"
      description = "Application logs"
    }
  }
}

output "volume_usage_example" {
  description = "How to use host volumes in a job"
  value       = <<-EOT
    # In your job spec:
    group "mygroup" {
      volume "mydata" {
        type   = "host"
        source = "data"  # matches host_volume name
      }

      task "mytask" {
        volume_mount {
          volume      = "mydata"
          destination = "/app/data"
        }
      }
    }
  EOT
}
