# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
# deploy Dgraph cluster
helmfile --file $HELMFILE apply
```

#### Adding Network Policy

This policy will deny traffic that is outside of the service mesh.

NOTE: This requires a network plugin that supports network policies, such as Calico, to be installed previously.

```bash
kubectl apply -f network_policy.yaml
```
