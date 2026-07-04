# Testing Ingress with ALB

## Setup

Isolate your testing workspace by creating a dedicated namespace and switching your active context:

```bash
kubectl create namespace demo-alb
kubectl config set-context --current --namespace=demo-alb
```

## Deploy Application

Deploy the application pod instance and expose it internally within the cluster:

```bash
kubectl create deployment demo-alb-app \
  --image=nginx:alpine
kubectl expose deployment demo-alb-app --port=80
```

## Provision Endpoint

You can provision the routing infrastructure using a static manifest configuration:

```bash
kubectl apply --filename ing.yaml
```

*Alternatively, skip the manifest entirely and jump to the Extra section below to create the Ingress rule using an imperative pipeline.*

## Verify

Monitor the generation and operational status of your newly provisioned application and routing components:

```bash
kubectl get all,ing,targetgroupbinding
```

## Test

Because AWS provisions the Application Load Balancer asynchronously, fetch the dynamic DNS hostname via `JSONPath`. Since the ALB routes based on host-matching headers, pass the targeted domain explicitly in the curl execution:

```bash
# Extract the ALB address from the Ingress status
EXTERNAL_IP=$(kubectl get ingress demo-alb-app \
  --namespace "demo-alb" \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test it using curl by passing the expected Host header
curl -i -H "Host: demo.example.com" http://$EXTERNAL_IP

```

## Cleanup

Tear down the deployment, service endpoints, Ingress configurations, and namespace cleanly to avoid racking up cloud charges:

```bash
kubectl delete svc,deploy,ing demo-alb-app
kubectl config set-context --current --namespace=default
kubectl delete ns demo-alb

```

## Extra: Ingress via Imperative Pipeline

If you prefer not to manage static YAML files, use this client-side pipeline. It generates the Ingress template natively with your routing rule, injects the AWS Application Load Balancer parameters, specifies high-performance `ip` target routing, and applies it straight to your cluster:

```bash
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
```