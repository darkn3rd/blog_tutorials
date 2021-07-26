# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
./deploy_dgraph.sh
```

### Adding Network Policy

```bash
kubectl --namespace "dgraph" -f net_policy.yaml
```
