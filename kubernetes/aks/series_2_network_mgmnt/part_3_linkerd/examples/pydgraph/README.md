# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
./deploy_pydgraph_client.sh
```

## Running Tools in Client Container

```bash
PYDGRAPH_POD=$(kubectl get pods --namespace pydgraph-client --output name)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} --container "pydgraph-client" -- bash
```
