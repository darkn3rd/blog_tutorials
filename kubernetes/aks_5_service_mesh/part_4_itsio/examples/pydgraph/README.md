# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
# create namespace first to enable inject
kubectl get namespace "pydgraph-client" > /dev/null 2> /dev/null || \
 kubectl create namespace "pydgraph-client" && \
 kubectl label namespaces "pydgraph-client" name="pydgraph-client" && \
 kubectl label namespace "pydgraph-client" istio-injection="enabled"

# deploy Dgraph cluster
helmfile --file $HELMFILE apply
```

## Running Tools in Client Container

```bash
PYDGRAPH_POD=$(kubectl get pods --namespace pydgraph-client --output name)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} -- bash
```


##

```bash
curl "${DGRAPH_ALPHA_SERVER}:8080/query" --silent --request POST \
  --header "Content-Type: application/dql" \
  --data $'{ me(func: has(starring)) { name } }'

```
