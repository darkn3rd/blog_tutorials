#!/usr/bin/env bash
source env.sh

# install cert-manager (must be before nginx_ic)
helmfile --file ./kube_addons/cert_manager/helmfile.yaml apply
helmfile --file ./kube_addons/cert_manager/issuers.yaml apply

# install kics (depends on cert_manager)
export NGINX_APP_PROTECT=true
helmfile --file ./kube_addons/nginx_ic/helmfile.yaml apply

# isntall external-dns (depends on nginx_ic)
helmfile --file ./kube_addons/external_dns/helmfile.yaml apply

# deploy ratel
kubectl get namespace "ratel" > /dev/null 2> /dev/null \
 || kubectl create namespace "ratel" \
 && kubectl label namespaces "ratel" name="ratel"

helmfile --file ratel/helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "ratel" --filename -

# Deploy load-balancers
helmfile --file ./ratel/vs.yaml apply
export MY_IP_ADDRESS=$(curl --silent ifconfig.me)
helmfile --file ./dgraph/vs.yaml apply

# Redeploy NSM
# export NSM_ACCESS_CONTROL_MODE=deny
# helmfile --file ./nsm/helmfile.yaml apply
# kubectl delete --namespace "nginx-mesh" \
#   $(kubectl get pods --namespace "nginx-mesh" --selector "app.kubernetes.io/name=nginx-mesh-api" --output name)
# nginx-meshctl config | jq -r .accessControlMode

# Try Client
export CLIENT_NAMESPACE="pydgraph-client"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NAMESPACE --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NAMESPACE ${PYDGRAPH_POD} -- bash

# SHOULD FAIL
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion

# SHOULD FAIL
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state
