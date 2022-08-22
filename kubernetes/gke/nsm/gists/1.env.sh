export GKE_PROJECT_ID="<your-project-name-goes-here>"
export GCR_PROJECT_ID=$GKE_PROJECT_ID
export GKE_REGION="us-central1"
export GKE_CLUSTER_NAME="nsm-cluster"
export GKE_SA_NAME="worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

export KUBECONFIG=~/.kube/$REGION-$GKE_CLUSTER_NAME.yaml
