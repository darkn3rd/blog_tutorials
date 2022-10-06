#!/usr/bin/env bash

source ./scripts/env.sh

# cloud resources
./scripts/gke.sh

gsutil iam ch \
  serviceAccount:$GKE_SA_EMAIL:objectViewer \
  gs://artifacts.$GCR_PROJECT_ID.appspot.com


# deploy ccsm
helmfile --file ./consul/helmfile.yaml apply
helmfile --file ./o11y/helmfile.yaml apply

# deploy dgraph
helmfile --file ./examples/dgraph/helmfile.yaml apply

pushd examples
git clone --depth 1 --branch "consul" git@github.com:darkn3rd/pydgraph-client.git
popd

# deploy negative test
unset CSM_ENABLED
helmfile --file ./examples/pydgraph-client/helmfile.yaml --namespace pydgraph-no-mesh apply

# deploy pydgraph-client
export CCSM_ENABLED=true
helmfile --file ./examples/pydgraph-client/helmfile.yaml apply

###########################################
# TESTING - POSTIVE TEST
###########################################
CLIENT_NS="pydgraph-client"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NS --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NS \
  ${PYDGRAPH_POD} -- bash

# INSIDE THE CONTAINER
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health | jq
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state | jq
grpcurl -plaintext -proto api.proto ${DGRAPH_GRPC_SERVER}:9080 api.Dgraph/CheckVersion

python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_GRPC_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema ./sw.schema
exit

###########################################
# TESTING - NEGATIVE TEST
###########################################
CLIENT_NS="pydgraph-no-mesh"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NS --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NS \
  ${PYDGRAPH_POD} -- bash

# INSIDE THE CONTAINER
DGRAPH_GRPC_SERVER=dgraph-dgraph-alpha-grpc.dgraph.svc.cluster.local
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health # expect to fail
grpcurl -plaintext -proto api.proto ${DGRAPH_GRPC_SERVER}:9080 api.Dgraph/CheckVersion


###########################################
# CLEAN
###########################################
helmfile --file ./examples/dgraph/helmfile.yaml delete
kubectl delete pvc --selector app=dgraph --namespace "dgraph"

helmfile --file ./consul/helmfile.yaml delete
kubectl delete pvc --selector app=consul --namespace "consul"

helmfile --file ./client/examples/pydgraph/helmfile.yaml --namespace "pydgraph-no-mesh" delete
helmfile --file ./clients/examples/pydgraph/helmfile.yaml delete

# cloud resources
gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION
