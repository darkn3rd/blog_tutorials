# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
# create namespace first to enable inject
kubectl get namespace "dgraph" > /dev/null 2> /dev/null || \
 kubectl create namespace "dgraph" && \
 kubectl label namespaces "dgraph" name="dgraph" &&
 kubectl label namespace "dgraph" istio-injection="enabled"

# deploy Dgraph cluster
helmfile --file $HELMFILE apply
```

#### Adding Network Policy

```bash
kubectl apply -f network_policy.yaml
```
