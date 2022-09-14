# Kubernetes Resources - dgraph
kubectl delete svc,sts,cm --selector app=dgraph --namespace "dgraph"
kubectl delete pvc --selector app=dgraph --namespace "dgraph"
# delete namespace, configmap, secret
kubectl delete namespace "dgraph"

# delete positive-test client
kubectl delete deploy/pydgraph-client --namespace "pydgraph-client"
kubectl delete namespace "pydgraph-client"
# delete negative-test client
helm delete "pydgraph-client" --namespace "pydgraph-no-mesh"

# delete service mesh
helm delete "nsm" --namespace"nginx-mesh"


# Google Cloud Resources
gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION
gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
