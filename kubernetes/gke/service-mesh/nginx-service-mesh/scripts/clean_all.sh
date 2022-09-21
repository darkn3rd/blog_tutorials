
# Ratel Resources

kubectl delete svc/dgraph-ratel --namespace "ratel"
kubectl delete deploy/dgraph-ratel --namespace "ratel"

# VirtualServers
helm delete dgraph-virtualservers --namespace "dgraph"
helm delete ratel-virtualserver --namespace "ratel"

# Kubernetes Addons
helm delete "external-dns" --namespace "kube-addons"
helm delete "nginx-ingress" --namespace "kube-addons"
helm delete "cert-manager-issuers" --namespace "kube-addons"
helm delete "cert-manager" --namespace "kube-addons"

# Kubernetes Resources - dgraph
kubectl delete svc,sts,cm --selector app=dgraph --namespace "dgraph"
kubectl delete pvc --selector app=dgraph --namespace "dgraph"

# delete positive-test client
kubectl delete deploy/pydgraph-client --namespace "pydgraph-client"
# delete negative-test client
helm delete "pydgraph-client" --namespace "pydgraph-no-mesh"

# delete service mesh
helm delete "nsm" --namespace "nginx-mesh"
kubectl delete pvc/spire-data-spire-server-0 --namespace "nginx-mesh"

# delete o11y (helmfile)
helmfile --file o11y/helmfile.yaml delete


gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION

# Remove Bindings
gcloud projects remove-iam-policy-binding $DNS_PROJECT_ID \
   --member serviceAccount:$DNS_SA_EMAIL --role "roles/dns.admin"
gcloud iam service-accounts remove-iam-policy-binding $DNS_SA_EMAIL \
  --project $GKE_PROJECT_ID \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${EXTERNALDNS_NS:-"default"}/external-dns]"
gcloud iam service-accounts remove-iam-policy-binding $DNS_SA_EMAIL \
  --project $GKE_PROJECT_ID \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${CERTMANAGER_NS:-"default"}/cert-manager]"

# Remove DNS GSA
gcloud iam service-accounts delete $DNS_SA_EMAIL --project $DNS_PROJECT_ID

# Remove GKE cluser
gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION

# Remove GKE worker GSA
gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
