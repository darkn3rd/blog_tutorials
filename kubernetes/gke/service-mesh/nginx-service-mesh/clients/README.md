# Clients

These set of scripts build a docker image with some data and a client script `load_data.py` that uses pydgraph module.  This script will load the Getting Started data using gRPC.


# Build and publish client image

```bash
#######################
# Download Setup Environment
##########################################
./fetch_scripts.sh

#######################
# Push pydgraph-client into GCR
##########################################
pushd examples/pydgraph
make build
make push
popd
```

# Deploy Client (Positive Test)

```bash
kubectl get namespace "pydgraph-client" > /dev/null 2> /dev/null \
 || kubectl create namespace "pydgraph-client" \
 && kubectl label namespaces "pydgraph-client" name="pydgraph-client"

helmfile --file ./examples/pydgraph/helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "pydgraph-client" --filename -
```

# Deploy Client (Negative Test)

```bash
helmfile --file ./examples/pydgraph/helmfile.yaml --namespace "pydgraph-no-mesh" apply
```

# Test Client Image

## Set Environment

```bash
# POSITIVE tests
export CLIENT_NAMESPACE="pydgraph-client"

# NEGATIVE tests
export CLIENT_NAMESPACE="pydgraph-no-mesh"

```


## Run Negative Tests

```bash
export CLIENT_NAMESPACE="pydgraph-no-mesh"

#######################
# Exec into pydgraph-client
##########################################
PYDGRAPH_POD=$(
  kubectl get pods --namespace $CLIENT_NAMESPACE --output name
)

kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NAMESPACE \
  ${PYDGRAPH_POD} -- bash
```

These tests are expected to fail:

```bash
# test gRPC connection
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion

# test HTTP connection
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health
echo $?
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state
echo $?

#######################
# Load Data with pydgraph-client
##########################################
python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema ./sw.schema
```

## Run Postive Tests

```bash
export CLIENT_NAMESPACE="pydgraph-client"


#######################
# Exec into pydgraph-client
##########################################
PYDGRAPH_POD=$(
  kubectl get pods --namespace $CLIENT_NAMESPACE --output name
)

kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NAMESPACE \
  ${PYDGRAPH_POD} -- bash
```

These are expected to work: 

```bash
# test gRPC connection
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion

# test HTTP connection
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health | jq
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state | jq

#######################
# Load Data with pydgraph-client
##########################################
python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema ./sw.schema
```
