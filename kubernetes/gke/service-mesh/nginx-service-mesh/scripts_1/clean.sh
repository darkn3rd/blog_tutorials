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
helm delete "nsm" --namespace "nginx-mesh"
kubectl delete pvc/spire-data-spire-server-0 --namespace "nginx-mesh"

# delete o11y
kubectl delete deploy/jaeger --namespace "nsm-monitoring"
kubectl delete deploy/grafana --namespace "nsm-monitoring"
kubectl delete deploy/otel-collector --namespace "nsm-monitoring"
kubectl delete deploy/prometheus --namespace "nsm-monitoring"
kubectl delete svc/jaeger --namespace "nsm-monitoring"
kubectl delete svc/grafana --namespace "nsm-monitoring"
kubectl delete svc/otel-collector --namespace "nsm-monitoring"
kubectl delete svc/prometheus --namespace "nsm-monitoring"
kubectl delete namespace "nsm-monitoring"

# Google Cloud Resources
gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION
gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
