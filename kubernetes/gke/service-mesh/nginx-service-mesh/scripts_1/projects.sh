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
