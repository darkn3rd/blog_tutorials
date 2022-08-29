
# gke
export GKE_PROJECT_ID="my-gke-project" # CHANGE ME
export GKE_CLUSTER_NAME="my-external-dns-cluster" # CHANGE ME
export GKE_REGION="us-central1"
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"
export KUBECONFIG=~/.kube/$REGION-$GKE_CLUSTER_NAME.yaml

# gcr (container registry)
export GCR_PROJECT_ID="my-gcr-project"

# external-dns + cloud-dns
export DNS_PROJECT_ID="my-cloud-dns-project" # CHANGE ME
export DNS_DOMAIN="example.com" # CHANGE ME
export EXTERNALDNS_LOG_LEVEL="debug"
export EXTERNALDNS_NS="kube-addons"
export CERTMANAGER_NS="kube-addons"
export DNS_SA_NAME="cloud-dns-sa"
export DNS_SA_EMAIL="$DNS_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

# cert-manager
export ACME_ISSUER_EMAIL="user@example.com" # CHANGE ME
export ACME_ISSUER_NAME="letsencrypt-prod"

# other
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export ClOUD_BILLING_ACCOUNT="<my-cloud-billing-account>" # CHANGEME
