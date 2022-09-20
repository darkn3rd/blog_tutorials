source env.sh

#######################
# GSA with least priv for GKE
##########################################
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

#######################
# GKE with least priv. GSA + Workgroup Identity
##########################################
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"

#######################
# KUBECONFIG
##########################################
gcloud container clusters  get-credentials $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION
