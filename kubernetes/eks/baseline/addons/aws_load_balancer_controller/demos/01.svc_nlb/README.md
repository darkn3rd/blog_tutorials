# Testing Service with NLB

## Setup

Isolate your testing workspace by creating a dedicated namespace and switching your active context:

```bash
kubectl create namespace demo-nlb
kubectl config set-context --current --namespace=demo-nlb
```

## Deploy

Deploy the application instance. 

> 📓 **NOTE**: You can provision using the manifest or alternative jump down to the Extra section to generate it purely via the CLI.

```bash
kubectl create deployment demo-nlb-app \
  --image=nginx:alpine

# Provision using manifest
kubectl apply --filename svc.yaml
```

## Test

Because AWS provisions the Network Load Balancer asynchronously, fetch the dynamic DNS hostname via `JSONPath` and query it:

```bash
EXTERNAL_IP=$(kubectl get service demo-nlb-app \
  --namespace "demo-nlb" \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)

curl -i $EXTERNAL_IP
```

## Cleanup

Tear down the deployment, service endpoints, and namespace cleanly to avoid racking up cloud charges:

```bash
kubectl delete svc,deploy demo-nlb-app
kubectl config set-context --current --namespace=default
kubectl delete ns demo-nlb

```

## Extra: Service via Imperative Pipeline

If you prefer not to manage static YAML files, use this client-side pipeline. It generates the service manifest template, dynamically injects the modern AWS Load Balancer Controller annotations (forcing direct ip mode routing), and applies it directly to your cluster:

```bash
kubectl expose deployment demo-nlb-app \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer \
  --dry-run=client \
  --output yaml \
| kubectl annotate --filename - \
  "service.beta.kubernetes.io/aws-load-balancer-type=external" \
  "service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing" \
  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type=ip" \
  --local \
  --output yaml \
| kubectl apply --filename -
```