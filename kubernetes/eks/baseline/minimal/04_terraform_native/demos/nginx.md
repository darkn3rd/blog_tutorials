# NGINX Demo

## Setup

```bash
# use namespace
kubectl create namespace demo
kubectl config set-context --current --namespace=demo
```

## Create

```bash
# create demo web application
kubectl create deployment demo-lb-app --image=nginx:alpine
kubectl expose deployment demo-lb-app --port=80 --type=LoadBalancer

# verify service
kubectl get services
```

## Test

```bash
DEMO_ADDR=$(kubectl get service demo-lb-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)

curl -i "$DEMO_ADDR"
```

## Cleanup

```bash
kubectl delete service demo-lb-app
kubectl delete deploy demo-lb-app
```