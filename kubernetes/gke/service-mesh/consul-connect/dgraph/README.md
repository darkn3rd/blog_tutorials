# Deploying Dgraph


These needs to be added to Zero and Alpha STS:

```yaml
spec.template.metadata.annotations:
  consul.hashicorp.com/connect-inject: "true"
  consul.hashicorp.com/transparent-proxy: "true"
```

These need to be added to headless SVCs for Alpha and Zero:

```yaml
metadata.labels:
  consul.hashicorp.com/service-ignore: 'true'
```
