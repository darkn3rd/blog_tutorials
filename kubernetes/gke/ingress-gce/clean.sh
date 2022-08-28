gcloud container clusters delete $GKE_CLUSTER_NAME --project $GKE_PROJECT_ID --region $GKE_REGION
gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
gcloud iam service-accounts delete $DNS_SA_EMAIL --project $GKE_PROJECT_ID
