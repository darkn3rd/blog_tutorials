# Clients

These set of scripts build a docker image with some data and a client script `load_data.py` that uses pydgraph module.  This script will load the Getting Started data using gRPC.

```bash
#######################
# Download Setup Environment
##########################################
USER="darkn3rd"
GIST_ID="414d9525ca4f3be0a58799ec2a10f6b3"
VERS="0247468063740eb969a84c6d82575202c5997aa7"
FILE="setup_pydgraph_gcp.sh"
URL=https://gist.githubusercontent.com/$USER/$GIST_ID/raw/$VERS/$FILE
curl -s $URL | bash -s --

#######################
# Push pydgraph-client into GCR
##########################################
make build
make push

#######################
# Deploy pydgraph-client
##########################################
helmfile apply
```



```bash
#######################
# Exec into pydgraph-client
##########################################
PYDGRAPH_POD=$(
  kubectl get pods --namespace "pydgraph-client" --output name
)

kubectl exec -ti --namespace "pydgraph-client" \
  ${PYDGRAPH_POD} -- bash
```

```bash
export DGRAPH_ALPHA_SERVER="<varies>"

# test gRPC connection
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion

# test HTTP connection
curl ${DGRAPH_ALPHA_SERVER}:8080/health | jq

#######################
# Load Data with pydgraph-client
##########################################
python3 load_data.py \
  --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema ./sw.schema
```
