job "hostpath" {
  datacenters = ["dc1"]
  namespace   = "default"
  type        = "system"

  group "plugin" {
    task "plugin" {
      driver = "docker"

      config {
        image      = "registry.k8s.io/sig-storage/hostpathplugin:v1.13.0"
        privileged = true
        args = [
          "--drivername=csi-hostpath",
          "--v=5",
          "--endpoint=unix:///csi/csi.sock",
          "--nodeid=${node.unique.name}",
        ]

        mount {
          type     = "bind"
          source   = "/var/lib/csi-hostpath"
          target   = "/var/lib/csi-hostpath"
          readonly = false
        }
      }

      csi_plugin {
        id        = "hostpath"
        type      = "monolith"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
