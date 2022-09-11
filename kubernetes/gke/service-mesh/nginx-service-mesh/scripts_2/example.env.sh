# external-dns + cloud-dns
export DNS_PROJECT_ID="my-cloud-dns-project" # CHANGE ME
export DNS_DOMAIN="example.com" # CHANGE ME
export EXTERNALDNS_LOG_LEVEL="debug"
export EXTERNALDNS_NS="kube-addons"
export CERTMANAGER_NS="kube-addons"
export DNS_SA_NAME="cloud-dns-sa"
export DNS_SA_EMAIL="$DNS_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

# gcr (container registry)
export GCR_PROJECT_ID="my-gcr-project"

# cert-manager
export ACME_ISSUER_EMAIL="user@example.com" # CHANGE ME
export ACME_ISSUER_NAME="letsencrypt-prod"
