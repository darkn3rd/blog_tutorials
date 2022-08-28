GKE_CLUSTER_NAME="my-external-dns-cluster"
GKE_REGION="us-central1"
GKE_SA_NAME="worker-nodes-sa"
GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

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
# GKE with least priv. GSA
##########################################
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"


#######################
# WORKLOAD IDENTITY
##########################################
DNS_SA_NAME="external-dns-sa"
DNS_SA_EMAIL="$DNS_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create $DNS_SA_NAME --display-name $DNS_SA_NAME
gcloud projects add-iam-policy-binding $DNS_PROJECT_ID \
   --member serviceAccount:$DNS_SA_EMAIL --role "roles/dns.admin"

# LINK KSA-to-GSA
gcloud iam service-accounts add-iam-policy-binding $DNS_SA_EMAIL \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${EXTERNALDNS_NS:-"default"}/external-dns]"

# Post Deployment LINK GSA-to-KSA
kubectl annotate serviceaccount "external-dns" \
  --namespace ${EXTERNALDNS_NS:-"default"} \
  "iam.gke.io/gcp-service-account=$DNS_SA_EMAIL"

# Patch POD Spec
kubectl patch deployment "external-dns" \
  --namespace ${EXTERNALDNS_NS:-"default"} \
  --patch \
 '{"spec": {"template": {"spec": {"nodeSelector": {"iam.gke.io/gke-metadata-server-enabled": "true"}}}}}'
