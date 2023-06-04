# Dgraph


## Simple storage 

```bash
helm install "ex" dgraph/dgraph \
  --namespace "dgraph" \
  --create-namespace \
  --set zero.persistence.storageClass=ebs-sc \
  --set alpha.persistence.storageClass=ebs-sc
```


## Cleanup

```bash
helm delete "ex" --namespace "dgraph"
kubectl delete pvc --selector release="ex" --namespace dgraph
```