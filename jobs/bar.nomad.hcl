job "bar" {
  region      = "global"
  datacenters = ["local-dc"]
  type        = "service"

  group "group" {
    count = 1

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "1m"
    }

    task "app" {
      driver = "docker"

      config {
        image   = "busybox:latest"
        command = "sleep"
        args    = ["3600"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
