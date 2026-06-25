kubectl create namespace demo-alb
kubectl config set-context --current --namespace=demo-alb

kubectl create deployment demo-alb-app \
  --image=nginx:alpine
kubectl expose deployment demo-alb-app --port=80

kubectl create ingress demo-alb-app \
  --rule="demo.example.com/*=demo-alb-app:80" \
  --dry-run=client \
  --output yaml \
| kubectl annotate --filename - \
    kubernetes.io/ingress.class=alb \
    alb.ingress.kubernetes.io/scheme=internet-facing \
    alb.ingress.kubernetes.io/target-type=ip \
    --local \
    --output yaml \
| kubectl apply --filename -

export ALB=$(kubectl get ingress demo-alb \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)

curl -v -H "Host: demo.example.com" http://$ALB


kubectl delete deploy,svc,ing demo-alb-app
kubectl config set-context --current --namespace=default
kubectl delete namespace demo-alb

