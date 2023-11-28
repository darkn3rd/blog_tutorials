
RELEASE_NAME=${RELEASE_NAME:-"dg"}
helm delete $RELEASE_NAME --namespace dgraph
kubectl delete pvc --namespace dgraph --selector release=$RELEASE_NAME
kubectl delete namespace dgraph