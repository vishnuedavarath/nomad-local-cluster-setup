# Host Volumes for Persistent Storage
# These are simpler than CSI for local clusters.

resource "null_resource" "setup_host_volumes" {
  count = length(data.terraform_remote_state.cluster.outputs.client_names)

  triggers = {
    client_name = data.terraform_remote_state.cluster.outputs.client_names[count.index]
    version     = "2"
  }

  provisioner "local-exec" {
    command = <<-EOT
      CLIENT="${data.terraform_remote_state.cluster.outputs.client_names[count.index]}"

      multipass exec $CLIENT -- bash -c '
        sudo mkdir -p /opt/nomad/volumes/{data,secrets,logs}
        sudo chmod 777 /opt/nomad/volumes/data
        sudo chmod 700 /opt/nomad/volumes/secrets
        sudo chmod 755 /opt/nomad/volumes/logs

        sudo tee /etc/nomad.d/host-volumes.hcl > /dev/null <<EOF

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
      '
    EOT
  }
}

resource "null_resource" "wait_for_clients" {
  depends_on = [null_resource.setup_host_volumes]

  provisioner "local-exec" {
    command = "sleep 5"
  }
}

resource "nomad_job" "volume_demo" {
  depends_on = [null_resource.wait_for_clients]

  jobspec = <<-EOT
    job "volume-demo" {
      datacenters = ["dc1"]
      namespace   = "development"
      type        = "service"

      group "app" {
        count = 1

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

          volume_mount {
            volume      = "data"
            destination = "/data"
          }

          volume_mount {
            volume      = "secrets"
            destination = "/app/secrets"
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
