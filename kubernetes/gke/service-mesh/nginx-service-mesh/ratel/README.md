
```bash
kubectl get namespace "ratel" > /dev/null 2> /dev/null \
 || kubectl create namespace "ratel" \
 && kubectl label namespaces "ratel" name="ratel"

helmfile --file helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "ratel" --filename -

helmfile -f vs.yaml apply 
```
