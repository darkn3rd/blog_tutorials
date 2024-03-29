# enable billing and APIs for DNS project if not done already
gcloud projects create $DNS_PROJECT_ID
gcloud config set project $DNS_PROJECT_ID
gcloud beta billing projects link $CLOUD_DNS_PROJECT \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "dns.googleapis.com"

# enable billing and APIs for GKE project if not done already
gcloud projects create $GKE_PROJECT_ID
gcloud config set project $GKE_PROJECT_ID
gcloud beta billing projects link $CLOUD_DNS_PROJECT \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "container.googleapis.com"
