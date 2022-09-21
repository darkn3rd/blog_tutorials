#!/usr/bin/env bash
#########
# This script runs all the functionality
# in a single script from both part 1 and part 2
######################################
source env.sh

#########
# PROJECTS
######################################

# enable billing and APIs for DNS project if not done already
gcloud projects create $DNS_PROJECT_ID
gcloud config set project $DNS_PROJECT_ID
gcloud beta billing projects link $DNS_PROJECT_ID \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "dns.googleapis.com"

# enable billing and APIs for GCR if not done already
gcloud projects create $GCR_PROJECT_ID
gcloud config set project $GCR_PROJECT_ID
gcloud beta billing projects link $GCR_PROJECT_ID \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "containerregistry.googleapis.com" # Enable GCR API

# enable billing and APIs for GKE project if not done already
gcloud projects create $GKE_PROJECT_ID
gcloud config set project $GKE_PROJECT_ID
gcloud beta billing projects link $CLOUD_DNS_PROJECT \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "container.googleapis.com"

#########
# Google Cloud Resources
######################################

###### GKE GSA #########
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

gcloud iam service-accounts create $GKE_SA_NAME \
  --display-name $GKE_SA_NAME --project $GKE_PROJECT_ID

# assign google service account to roles in GKE project
for ROLE in ${ROLES[*]}; do
  gcloud projects add-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE
done

###### GKE #########
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"

###### KUBECONFIG #########
gcloud container clusters  get-credentials $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION

###### GCR - GKE SA Access #########
gsutil iam ch \
  serviceAccount:$GKE_SA_EMAIL:objectViewer \
  gs://artifacts.$GCR_PROJECT_ID.appspot.com

###### CLOUD DNS SA #########
gcloud iam service-accounts create $DNS_SA_NAME --display-name $DNS_SA_NAME
gcloud projects add-iam-policy-binding $DNS_PROJECT_ID \
   --member serviceAccount:$DNS_SA_EMAIL --role "roles/dns.admin"

# LINK ExternalDNS KSA to Cloud DNS GSA
gcloud iam service-accounts add-iam-policy-binding $DNS_SA_EMAIL \
  --project $GKE_PROJECT_ID \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${EXTERNALDNS_NS:-"default"}/external-dns]"

# LINK CertManager KSA to Cloud DNS GSA
gcloud iam service-accounts add-iam-policy-binding $DNS_SA_EMAIL \
  --project $GKE_PROJECT_ID \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${CERTMANAGER_NS:-"default"}/cert-manager]"


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


#########
# KUBE-ADDONS
######################################

# install cert-manager (must be before nginx_ic)
helmfile --file ./kube_addons/cert_manager/helmfile.yaml apply
helmfile --file ./kube_addons/cert_manager/issuers.yaml apply

# isntall kics (depends on cert_manager)
export NGINX_APP_PROTECT=true
helmfile --file ./kube_addons/nginx_ic/helmfile.yaml apply

# isntall external-dns (depends on nginx_ic)
helmfile --file ./kube_addons/external_dns/helmfile.yaml apply

#########
# RATEL
######################################
# deploy ratel
kubectl get namespace "ratel" > /dev/null 2> /dev/null \
 || kubectl create namespace "ratel" \
 && kubectl label namespaces "ratel" name="ratel"

helmfile --file ratel/helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "ratel" --filename -

#########
# VirtualServers
######################################
helmfile --file ./ratel/vs.yaml apply
export MY_IP_ADDRESS=$(curl --silent ifconfig.me)
helmfile --file ./dgraph/vs.yaml apply
