kubectl create namespace demo-nlb
kubectl config set-context --current --namespace=demo-nlb

kubectl create deployment demo-nlb-app \
  --image=nginx:alpine

kubectl expose deployment demo-nlb-app\
  --port=80 \
  --type=LoadBalancer \
  --dry-run=client \
  --output yaml \
| kubectl annotate --filename - \
  "service.beta.kubernetes.io/aws-load-balancer-type=external" \
  "service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing" \
  --local \
  --output yaml \
| kubectl apply --filename -


kubectl delete svc,deploy demo-nlb-app
kubectl config set-context --current --namespace=default
kubectl delete namespace demo-nlb

