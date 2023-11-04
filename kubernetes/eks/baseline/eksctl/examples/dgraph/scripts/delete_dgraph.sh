helm delete "dg" --namespace "dgraph"
kubectl delete pvc --selector release="dg" --namespace dgraph
