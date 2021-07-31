# Pydgraph

For this exercise, the pydgraph client will be deployed twice to two different namespaces:

* namespace `pydgraph-allow` - will have the envoy proxy
* namespace `pydgraph-deny` - will not have the envoy proxy

## Deploy pydgraph-deny

```bash
helmfile --namespace "pydgraph-deny" apply
```

## Deploy pydgraph-allow

```bash
# create namespace  if it doesn't exist
kubectl get namespace "pydgraph-allow" > /dev/null 2> /dev/null || \
 kubectl create namespace "pydgraph-allow" && \
 kubectl label namespaces "pydgraph-allow" name="pydgraph-allow"

# add isio label so that pods will had envoy proxy
kubectl label namespace "pydgraph-allow" istio-injection="enabled"

# deploy pydgraph client
helmfile --namespace "pydgraph-allow" apply
```


## Login into Containers

### pydgraph-allow

```bash
PYDGRAPH_ALLOW_POD=$(kubectl get pods --namespace "pydgraph-allow" --output name)
kubectl exec -ti --namespace "pydgraph-allow" ${PYDGRAPH_ALLOW_POD} -- bash
```

### pydgraph-deny

```bash
PYDGRAPH_DENY_POD=$(kubectl get pods --namespace "pydgraph-deny" --output name)
kubectl exec -ti --namespace "pydgraph-deny" ${PYDGRAPH_DENY_POD} -- bash
```


```bash
for i in {1..1000}; do
  curl "${DGRAPH_ALPHA_SERVER}:8080/query" --silent --request POST \
    --header "Content-Type: application/dql" \
    --data $'{ me(func: has(starring)) { name } }'
done
```
