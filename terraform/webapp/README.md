# Webapp

Deploys a sample webapp (nginx by default) onto the local Nomad cluster with:

- **3 allocations by default** — controlled by `var.replicas`.
- **Consul service discovery** — every allocation registers under the Consul
  service `var.service_name` (default `webapp`) with an HTTP health check.
- **Autoscaler-ready** — a `scaling` stanza is attached by default so the
  job from the `terraform/autoscaler` workspace can horizontally scale it
  between `var.min_count` and `var.max_count` based on CPU usage.
- **Optional load balancer** — set `var.deploy_fabio_lb=true` to also
  deploy a small Fabio job that fronts every Consul service tagged
  `urlprefix-/`. Off by default; Consul service discovery is preferred.

## Usage

```sh
terraform init
terraform apply
```

Custom replica count or image:

```sh
terraform apply -var='replicas=5' -var='image=httpd:latest'
```

Also deploy the Fabio LB:

```sh
terraform apply -var='deploy_fabio_lb=true'
```

## Querying the webapp

Via Consul DNS (from any cluster node):

```sh
dig @127.0.0.1 -p 8600 webapp.service.consul
```

Via the Consul HTTP API:

```sh
curl "$CONSUL_HTTP_ADDR/v1/health/service/webapp?passing=true"
```

Via Fabio (if deployed): `http://<any-client-ip>:9999`.
