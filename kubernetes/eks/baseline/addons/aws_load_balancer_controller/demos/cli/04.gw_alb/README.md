# Testing Gateway with ALB

## Setup

Isolate your testing workspace by creating a dedicated namespace and switching your active context:

```bash
kubectl create namespace demo-gwhttp
kubectl config set-context --current --namespace=demo-gwhttp
```

## Deploy Application

Deploy the application pod instance and expose it internally within the cluster:

```bash
kubectl create deployment demo-gwhttp-app \
  --image=nginx:alpine

# Creates a standard internal ClusterIP entrypoint matching the manifest backendRef
kubectl expose deployment demo-gwhttp-app \
  --port=80 \
  --target-port=80
```

## Provision Endpoint

You can provision the L7 routing infrastructure, routing rules, and AWS health check configurations using a unified manifest:

```bash
kubectl apply --filename gwhttp.yaml
```

## Verify

Monitor the generation and operational status of your newly provisioned Gateway infrastructure components:

```bash
kubectl get all,gtw,gc,httproute,targetgroupbinding,targetgroupconfiguration,loadbalancerconfiguration
```

## Test

Because AWS provisions the Application Load Balancer asynchronously, fetch the dynamic DNS hostname via `JSONPath`. Since the ALB routes based on Layer 7 host-matching rules, pass the targeted domain explicitly in the request headers:

```bash
# Extract the ALB address from the Ingress status
EXTERNAL_IP=$(kubectl get gateway demo-gwhttp-app-gw \
  --output jsonpath='{.status.addresses[0].value}')

# Monitor until global AWS name servers populate the dynamic DNS record
while [ -z "$(dig +short "$EXTERNAL_IP")" ]; do
  echo "⏳ Waiting for ALB DNS to propagate..."
  sleep 15
done

# Test it using curl by passing the expected Host header
echo "✅ ALB is Live! Querying HTTPRoute:"
curl -i -H "Host: demo.example.com" "http://${EXTERNAL_IP}"
```

## Cleanup

Tear down the deployment, service endpoints, Gateway configurations, and namespace cleanly to avoid racking up unexpected cloud infrastructure charges:

```bash
kubectl delete --filename gwhttp.yaml
kubectl delete svc,deploy demo-gwhttp-app

kubectl config set-context --current --namespace=default
kubectl delete ns demo-gwhttp

```
