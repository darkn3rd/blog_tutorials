#!/usr/bin/env bash

pushd o11y && ./fetch_manifests.sh && popd
helmfile --file ./o11y/helmfile.yaml apply
helmfile --file ./nsm/helmfile.yaml apply

# Dgraph with manual injection + skip ports
kubectl get namespace "dgraph" > /dev/null 2> /dev/null \
 || kubectl create namespace "dgraph" \
 && kubectl label namespaces "dgraph" name="dgraph"

helmfile --file dgraph/helmfile.yaml template \
 | nginx-meshctl inject \
     --ignore-incoming-ports 5080,7080 \
     --ignore-outgoing-ports 5080,7080 \
 | kubectl apply --namespace "dgraph" --filename -


# Build Containers
pushd ./examples/pydgraph
make build
make push
popd
popd

# Positive Test Client
kubectl get namespace "pydgraph-client" > /dev/null 2> /dev/null \
 || kubectl create namespace "pydgraph-client" \
 && kubectl label namespaces "pydgraph-client" name="pydgraph-client"

helmfile --file ./clients/examples/pydgraph/helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "pydgraph-client" --filename -


helmfile \
  --file ./clients/examples/pydgraph/helmfile.yaml \
  --namespace "pydgraph-no-mesh" \
  apply
