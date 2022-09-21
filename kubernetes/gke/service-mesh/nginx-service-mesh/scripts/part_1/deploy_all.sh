#!/usr/bin/env bash
source env.sh

#########
# NSM + Observability
######################################
pushd o11y && ./fetch_manifests.sh && popd
helmfile --file ./o11y/helmfile.yaml apply
export NSM_ACCESS_CONTROL_MODE=allow # deny causes problems
helmfile --file ./nsm/helmfile.yaml apply

#########
# Dgraph with manual injection + skip ports
######################################
kubectl get namespace "dgraph" > /dev/null 2> /dev/null \
 || kubectl create namespace "dgraph" \
 && kubectl label namespaces "dgraph" name="dgraph"

helmfile --file dgraph/helmfile.yaml template \
 | nginx-meshctl inject \
     --ignore-incoming-ports 5080,7080 \
     --ignore-outgoing-ports 5080,7080 \
 | kubectl apply --namespace "dgraph" --filename -

#########
# Build Containers
######################################
pushd ./examples/pydgraph
gcloud auth configure-docker
make build
make push
popd
popd

#########
# Allow GCR  access
######################################
gsutil iam ch \
  serviceAccount:$GKE_SA_EMAIL:objectViewer \
  gs://artifacts.$GCR_PROJECT_ID.appspot.com

#########
# Positive Test Client
######################################
kubectl get namespace "pydgraph-client" > /dev/null 2> /dev/null \
 || kubectl create namespace "pydgraph-client" \
 && kubectl label namespaces "pydgraph-client" name="pydgraph-client"

helmfile --file ./clients/examples/pydgraph/helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "pydgraph-client" --filename -

#########
# Negative Test Client
######################################
helmfile \
  --file ./clients/examples/pydgraph/helmfile.yaml \
  --namespace "pydgraph-no-mesh" \
  apply
