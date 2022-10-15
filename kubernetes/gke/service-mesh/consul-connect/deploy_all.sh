#!/usr/bin/env bash

##############################
# deploy_all.sh
#
# this is a script to cpoy paste for compoents that you may want to use or test
#
##############################

# create ./scripts.env.sh
source ./scripts/env.sh

# cloud resources
./scripts/gke.sh

# deploy ccsm
unset CCSM_SECURITY_ENABLED
unset CCSM_METRICS_ENABLED
helmfile --file ./consul/helmfile.yaml apply

# deploy dgraph
helmfile --file ./examples/dgraph/helmfile.yaml apply

# deploy dgraph-client
helmfile --file ./examples/dgraph/pydgraph_client.yaml apply

#########################################################
# NOTE: Only use this for publishing images to GCR
#########################################################
gsutil iam ch \
  serviceAccount:$GKE_SA_EMAIL:objectViewer \
  gs://artifacts.$GCR_PROJECT_ID.appspot.com

pushd examples
git clone --depth 1 --branch "consul" git@github.com:darkn3rd/pydgraph-client.git
popd

###########################################
# TESTING
###########################################
CLIENT_NS="pydgraph-client"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NS --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NS \
  ${PYDGRAPH_POD} -- bash

# INSIDE THE CONTAINER
export DGRAPH_ALPHA_SERVER=localhost
export DGRAPH_GRPC_SERVER=localhost
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
# CLEAN
###########################################
helmfile --file ./examples/dgraph/helmfile.yaml delete
kubectl delete pvc --selector app=dgraph --namespace "dgraph"
kubectl delete namespace dgraph

helmfile --file ./consul/helmfile.yaml delete
kubectl delete pvc --selector app=consul --namespace "consul"
kubectl delete namespace consul # delete config/secrets

kubectl delete namespace pydgraph-client # delete config/secrets

# cloud resources
gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION
