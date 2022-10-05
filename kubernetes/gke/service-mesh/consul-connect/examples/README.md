

## Dgraph

### Dgraph Server

```bash
helmfile --file ./dgraph/helmfile.yaml apply
```

### Pydgraph Client

#### Deploy

```bash
git clone --depth 1 --branch "consul" git@github.com:darkn3rd/pydgraph-client.git
export CCSM_ENABLED="true"
helmfile --file ./pydgraph/helmfile.yaml apply
```

#### Test

Exec into container:

```bash
export CLIENT_NAMESPACE="pydgraph-client"
PYDGRAPH_POD=$(
  kubectl get pods --namespace $CLIENT_NAMESPACE --output name
)

kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NAMESPACE \
  ${PYDGRAPH_POD} -- bash
```

Run Tests:

```bash
# test HTTP connection
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health | jq
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state | jq

# test gRPC connection
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_GRPC_SERVER}:9080 \
  api.Dgraph/CheckVersion

python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_GRPC_SERVER}:9080 \
  --files ./data/sw.nquads.rdf \
  --schema ./data/sw.schema
```

## Greeter

Greeter application can be deployed using this:

```bash
git clone git@github.com:darkn3rd/greeter.git
export DOCKER_REGISTRY="darknerd"
export CCSM_ENABLED="true"
helmfile --file ./greeter/deploy/helmfile.yaml apply
```
