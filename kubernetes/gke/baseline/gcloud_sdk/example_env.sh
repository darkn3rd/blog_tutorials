# global var
export GKE_PROJECT_ID="base-gke"

# network vars
export GKE_NETWORK_NAME="base-main"
export GKE_SUBNET_NAME="base-private"
export GKE_ROUTER_NAME="base-router"
export GKE_NAT_NAME="base-nat"

# principal vars
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

# gke vars
export GKE_CLUSTER_NAME="base-gke"
export GKE_REGION="us-central1"
export GKE_MACHINE_TYPE="e2-standard-2"

# kubectl client vars
export USE_GKE_GCLOUD_AUTH_PLUGIN="True"
export KUBECONFIG=~/.kube/gcp/$GKE_REGION-$GKE_CLUSTER_NAME.yaml

# gke
export GKE_PROJECT_ID="base-gke"
export GKE_CLUSTER_NAME="base"
export GKE_REGION="us-central1"
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"
export KUBECONFIG=~/.kube/gcp/$GKE_REGION-$GKE_CLUSTER_NAME.yaml

# other
export ClOUD_BILLING_ACCOUNT="XXXXXX-XXXXXX-XXXXXX" # CHANGEME