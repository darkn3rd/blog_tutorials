source env.sh

##############
# STEP 1: Setup Projects
# Requirements: Assumes you have created a project and linked it
#  to a billing account
#########################
gcloud config set project $GKE_PROJECT_ID
gcloud config set compute/region $GKE_REGION

gcloud services enable "container.googleapis.com" # Enable GKE API
gcloud services enable "containerregistry.googleapis.com" # Enable GCR API

gcloud auth configure-docker

##############
# STEP 2: Create GSA (Google Service Account) used to securely run
#  Kubernetes Worker Nodes (GCE VM instances)
#########################
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

##############
# STEP 3: Create GKE (Google Kubernetes Engine) cluster
#########################
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"

##############
# STEP 4: Create KUBECONFIG entry to access GKE cluster
#########################
gcloud container clusters  get-credentials $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION
