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
LB=$(kubectl get svc web-pvc-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

kubectl exec deploy/web-pvc-demo -- sh -c \
  'echo "Updated at $(date) from pod $HOSTNAME" >> /usr/share/nginx/html/persist.txt'
curl "http://$LB/persist.txt"
# Created at Sun Jun 21 02:57:31 UTC 2026 from pod web-pvc-demo-77988cc7d8-znhh2
# Updated at Sun Jun 21 02:59:57 UTC 2026 from pod web-pvc-demo-77988cc7d8-znhh2

kubectl delete pod -l app=web-pvc-demo
kubectl rollout status deploy/web-pvc-demo

kubectl exec deploy/web-pvc-demo -- sh -c \
  'echo "Updated at $(date) from pod $HOSTNAME" >> /usr/share/nginx/html/persist.txt'

curl "http://$LB/persist.txt"

# Created at Sun Jun 21 02:57:31 UTC 2026 from pod web-pvc-demo-77988cc7d8-znhh2
# Updated at Sun Jun 21 02:59:57 UTC 2026 from pod web-pvc-demo-77988cc7d8-znhh2
# Updated at Sun Jun 21 03:01:08 UTC 2026 from pod web-pvc-demo-77988cc7d8-nrz2m
```



## Cleanup

```bash
# delete PVC and Deploy
kubectl delete --namespace demo --filename web_pvc.yaml
```
