# Web PVC Demo


## Setup

```bash
kubectl apply --filename sc.yaml
kubectl create namespace demo
kubectl config set-context --current --namespace=demo
```

## Deploy Application

```bash
kubectl apply --namespace demo --filename web_pvc.yaml
```

## Test

```bash
kubectl wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  svc/web-pvc-demo \
  --timeout=5m

LB=$(kubectl get svc web-pvc-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

kubectl exec deploy/web-pvc-demo -- sh -c \
  'echo "Updated at $(date) from pod $HOSTNAME" >> /usr/share/nginx/html/persist.txt'
  
curl "http://$LB/persist.txt"

# Run Test
kubectl delete pod -l app=web-pvc-demo
kubectl rollout status deploy/web-pvc-demo

kubectl exec deploy/web-pvc-demo -- sh -c \
  'echo "Updated at $(date) from pod $HOSTNAME" >> /usr/share/nginx/html/persist.txt'

curl "http://$LB/persist.txt"
```

## Cleanup

```bash
# delete PVC and Deploy
kubectl delete --namespace demo --filename web_pvc.yaml
```
