#!/usr/bin/env bash
source env.sh

# NOTE: This is experimenting.  Currently, gRPC always works, regardless of configuration.

# Redeploy NSM
export NSM_ACCESS_CONTROL_MODE=deny
helmfile --file ./nsm/helmfile.yaml apply
kubectl delete --namespace "nginx-mesh" \
  $(kubectl get pods --namespace "nginx-mesh" --selector "app.kubernetes.io/name=nginx-mesh-api" --output name)
nginx-meshctl config | jq -r .accessControlMode

###########################
# Execute into Client
##########################################
export CLIENT_NAMESPACE="pydgraph-client"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NAMESPACE --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NAMESPACE ${PYDGRAPH_POD} -- bash

# SHOULD FAIL (but does not)
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion

# SHOULD FAIL
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state
logout
