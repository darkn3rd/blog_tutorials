# Helmfile example

This is an example on how to use `helmfile` to coordinate installation of Prometheus, Grafana, Jaeger, MinIO, and Dgraph.

## Instructions

```bash
export GRAFANA_ADMIN_PASSWORD="password123"  # demo password only
helmfile apply
```
