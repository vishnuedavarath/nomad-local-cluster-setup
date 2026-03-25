job "nginx" {
  # Run this in our local datacenter
  datacenters = ["dc1"]
  type        = "service"

  meta = {
    environment = "dev"
    managed_by  = "terraform"
    app         = "nginx"
  }

  group "web" {
    # This tells Nomad to run 3 instances of Nginx (one for each client node)
    count = 3

    # update {
    #   max_parallel      = 1
    #   health_check      = "task_states"
    #   min_healthy_time  = "10s"
    #   healthy_deadline  = "2m"
    #   progress_deadline = "5m"
    #   auto_revert       = true
    # }

    network {
      # This exposes port 8080 on the client VMs
      port "http" {
        static = 8080
        to     = 80
      }
    }

    task "nginx" {
      # Use the Docker driver we installed via Ansible
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      # Tell Nomad how much CPU/RAM each container needs
      resources {
        cpu    = 100 # MHz
        memory = 128 # MB
      }
    }
  }
}
