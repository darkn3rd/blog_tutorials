# NGINX Service Mesh

1. Installing NSM + KIC (NGINX+) on GKE
2. Installing Dgraph + pydgraph client
   * Dgraph: ACLs enabled for tenants
3. Installing Ingress to access Dgraph
   * certificates
   * domain name service

## Dgraph Demo

Note:

1. Part of this demonstration with pydgraph to illustration GRPC traffic requires building a custom image, which uses Docker.
2. `pydgraph-client` namespace used for python client
3. maybe `ratel-client` namespace used for ratel client


```bash
curl ${DGRAPH_ALPHA_SERVER}:8080/health | jq
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion


pushd ./examples/pydgraph
make build && make push
helmfile apply
popd

PYDGRAPH_POD=$(kubectl get pods \
  --namespace pydgraph-client \
  --output name
)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} -- bash
```


### Generating Traffic

```bash
########
# HTTP requests
#################
curl ${DGRAPH_ALPHA_SERVER}:8080/health

########
# gRPC requests
#################
grpcurl -plaintext -proto api.proto \
 ${DGRAPH_ALPHA_SERVER}:9080 api.Dgraph/CheckVersion

########
# gRPC mutations
#################
python3 load_data.py --plaintext \
 --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
 --files ./sw.nquads.rdf \
 --schema ./sw.schema

########
# HTTP queries (DQL)
#################
curl "${DGRAPH_ALPHA_SERVER}:8080/query" --silent \
 --request POST \
 --header "Content-Type: application/dql" \
 --data $'{ me(func: has(starring)) { name } }'
```
