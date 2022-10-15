# Consul Connect Service Mesh

This is an example of how to deploy Consul Connect Service Mesh, now called Consul Service Mesh, and an example applicaton Dgraph.

## Prerequisites

Setup `./scripts/env.sh` with appropriate variables

```bash
source ./scripts/env.sh
bash ./scripts/gke.sh
```

## Deploying Consul Connect

```bash
unset CCSM_SECURITY_ENABLED
unset CCSM_METRICS_ENABLED
helmfile --file ./consul/helmfile.yaml apply
```

## Deploy Dgraph

```bash
helmfile --file ./examples/dgraph/helmfile.yaml apply
```

## Deploy Pydgraph Client

```bash
export CCSM_ENABLED="true"
helmfile --file ./examples/dgraph/pydgraph_client.yaml apply
```

## Testing Solution

```bash
# exec into container
CLIENT_NS="pydgraph-client"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NS --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NS \
  ${PYDGRAPH_POD} -- bash

# run inside the container
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health | jq
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state | jq
grpcurl -plaintext -proto api.proto ${DGRAPH_GRPC_SERVER}:9080 api.Dgraph/CheckVersion
python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_GRPC_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema ./sw.schema
exit
```
