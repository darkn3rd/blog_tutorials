# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
./deploy_dgraph.sh
```

### Adding Network Policy

When ready, apply the network policy to restrict traffic to namespaces with the label `app=dgraph-client`.

```bash
kubectl --namespace "dgraph" -f network_policy.yaml
```

## Verify Cluster

Check to see if all the pods and components are fully deployed:

```bash
kubectl --namespace dgraph get all
```

List the IP addressed used by Dgraph:

```bash
JSONPATH='{range .items[*]}{@.metadata.name}{"\t"}{@.status.podIP}{"\n"}{end}'
kubectl get pods --output jsonpath="$JSONPATH"
```
