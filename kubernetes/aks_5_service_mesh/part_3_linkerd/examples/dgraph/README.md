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

### Profile

```bash
curl -sOL https://raw.githubusercontent.com/dgraph-io/dgo/v210.03.0/protos/api.proto

linkerd profile \
 --proto api.proto \
 --namespace dgraph dgraph-svc | \
  kubectl apply --namespace "dgraph" --filename -
```
