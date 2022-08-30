# Kubernetes Resources - dgraph
helm delete "dgraph" --namespace "dgraph"
helm delete "ratel" --namespace "ratel"
# IMPORT: delete storage
kubectl delete pvc --selector app=dgraph --namespace "dgraph"

# Kubernetes Resources - kube-addons
helm delete "cert-manager" --namespace "kube-addons"
helm delete "cert-manager-issuers" --namespace "kube-addons"
helm delete "external-dns" --namespace "kube-addons"

# Google Cloud Resources
gcloud container clusters delete $GKE_CLUSTER_NAME --project $GKE_PROJECT_ID --region $GKE_REGION
gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
gcloud iam service-accounts delete $DNS_SA_EMAIL --project $GKE_PROJECT_ID
