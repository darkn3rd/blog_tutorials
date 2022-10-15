# Examples

These are some example programs.

## Dgraph

### Server: Dgraph

This has the necessary deployment code and patches to deploy Dgraph with support for Consul Connect service mesh.

```bash
helmfile --file ./dgraph/helmfile.yaml apply
```

### Client: Pydgraph client

The client is a small utility container that has a few tools that can be used interact with the Dgraph server through either HTTP or gRPC.  There is a python script that can be load data to the Dgraph server.

#### Deploy

```bash
# checkout dgraph with deployment code for Consul service mesh
git clone --depth 1 --branch "consul" git@github.com:darkn3rd/pydgraph-client.git
# enable Consul Connect service mesh
export CCSM_ENABLED="true"
# deploy pydraph client on the service mesh
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

# load data
python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_GRPC_SERVER}:9080 \
  --files ./data/sw.nquads.rdf \
  --schema ./data/sw.schema
```

## Greeter

Deploy Greeter

```bash
git clone git@github.com:darkn3rd/greeter.git
export DOCKER_REGISTRY="darknerd"
export CCSM_ENABLED="true"
helmfile --file ./greeter/deploy/helmfile.yaml apply
```

### Test

Exec into greeter:

```bash
GREETER_CLIENT_POD=$(kubectl get pods \
  --selector app=greeter-client \
  --namespace greeter-client \
  --output name
)

# exec into the container
kubectl exec --tty --stdin \
  --container "greeter-client" \
  --namespace "greeter-client" \
  $GREETER_CLIENT_POD \
  -- bash
```

Test HTTP and gRPC:

```bash
export CCSM_ENABLED="true" # set this ONLY if using consul connect

NS="greeter-server"
HTTP_SERVER="greeter-server.$NS.svc.cluster.local"
GRPC_SERVER="greeter-server-grpc.$NS.svc.cluster.local"

# test gRPC
grpcurl -plaintext -d '{ "name": "Michihito" }' $GRPC_SERVER:9080 helloworld.Greeter/SayHello

# test HTTP
curl $HTTP_SERVER:8080/SayHello/Michihito
```
