# Testing Gateway with NLB

## Setup

Isolate your testing workspace by creating a dedicated namespace and switching your active context:

```bash
kubectl create namespace demo-gwtcp
kubectl config set-context --current --namespace=demo-gwtcp
```

## Deploy

Deploy your application pods and expose them natively inside the cluster environment:

```bash
kubectl create deployment demo-gwtcp-app \
  --image=nginx:alpine
kubectl expose deployment demo-gwtcp-app \
  --port=80 \
  --target-port=80 \
  --type=ClusterIP
```

## Provision Endpoint

Provision your Layer 4 load balancing framework entirely from the CLI. This provisions the core Gateway definitions alongside the type-safe AWS parameters targeting direct Pod-to-NLB (ip) routing rules:

```bash
kubectl apply --namespace demo-gwtcp --filename gwtcp.yaml
```

## Verify

Monitor the generation and operational status of your newly provisioned Gateway infrastructure components:

```bash
kubectl get all,gtw,gc,tcproute,targetgroupbinding,targetgroupconfiguration,loadbalancerconfiguration
```

## Test

Because AWS provisions the Network Load Balancer asynchronously, fetch the dynamic DNS hostname via JSONPath.

To verify your environment, use this validation routine to monitor your public endpoint propagation until it resolves, then automatically fire your test request:

```bash
# Extract the public NLB address directly into your environment
EXTERNAL_IP=$(kubectl get gateway demo-gwtcp-app-gateway \
  --output jsonpath='{.status.addresses[0].value}')

# Wait until global AWS name servers populate the record
while [ -z "\$(dig +short "\$EXTERNAL_IP")" ]; do
  echo "⏳ Waiting for AWS DNS to propagate..."
  sleep 10
done

# Hit the endpoint (it may take a minute for AWS DNS to propagate)
# Hit the endpoint
echo "✅ NLB is Live! Querying service backend:"
curl -i "$EXTERNAL_IP"
```

## Cleanup

Tear down the deployment, service endpoints, and namespace cleanly to avoid racking up cloud charges:

```bash
kubectl delete --filename gwtcp.yaml
kubectl delete svc,deploy demo-gwtcp-app

kubectl config set-context --current --namespace=default
kubectl delete ns demo-gwtcp

```
