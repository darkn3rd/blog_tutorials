
# gke
export GKE_PROJECT_ID="my-gke-project" # CHANGE ME
export GKE_CLUSTER_NAME="csm-demo"
export GKE_REGION="us-central1"
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"
export KUBECONFIG=~/.kube/$GKE_REGION-$GKE_CLUSTER_NAME.yaml

# gcr
export GCR_PROJECT_ID="my-gcr-project"
export DOCKER_REGISTRY="gcr.io/$GCR_PROJECT_ID"

# other
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export ClOUD_BILLING_ACCOUNT="<my-cloud-billing-account>" # CHANGEME
