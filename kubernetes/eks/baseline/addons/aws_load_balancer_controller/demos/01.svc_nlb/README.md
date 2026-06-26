# Testing Service with NLB

## Setup

Isolate your testing workspace by creating a dedicated namespace and switching your active context:

```bash
kubectl create namespace demo-nlb
kubectl config set-context --current --namespace=demo-nlb
```

## Deploy

Deploy the application instance. 

```bash
kubectl create deployment demo-nlb-app \
  --image=nginx:alpine
```

## Provision Endpoint

You can provision the network service infrastructure using a static manifest configuration:

```bash
kubectl apply --filename svc.yaml
```

*Alternatively, skip the manifest entirely and jump down to the Extra section below to create the service using an imperative pipeline.*

## Test

Because AWS provisions the Network Load Balancer asynchronously, fetch the dynamic DNS hostname via `JSONPath` and query it:

```bash
# Extract the public NLB address directly into your environment
EXTERNAL_IP=$(kubectl get service demo-nlb-app \
  --namespace "demo-nlb" \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Hit the endpoint (it may take a minute for AWS DNS to propagate)
curl -i "$EXTERNAL_IP"
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