helm delete "ex" --namespace "dgraph"
kubectl delete pvc --selector release="ex" --namespace dgraph
