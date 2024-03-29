# Secure Multiport Example

This uses static server from Hashicorp documentation and tutorials.  There are no examples currently (2022-OCT-15) on multi-port + security.


# Instructions

## Deploy Consul

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com && helm repo update

# Delete namespace if it exists
kubectl delete namespace consul

helm upgrade consul hashicorp/consul \
  --namespace consul \
  --create-namespace \
  --version "0.43.0" \
  --values ./secure-dc1.yaml \
  --wait
```

## Test Security

Currently, with multi-port configuration, transparent-proxy no longer works, and you must setup upstream ports.  This means that security will only work through the mesh tunnel through localhost.  This also means that direct communication through the service DNS name will not only bypass the service mesh completely, and thus will not have encrypted traffic, but it will also not be denied when appropriate.

```bash
kubectl apply -f server.yaml
kubectl apply -f client.yaml
watch kubectl get pods # CTRL-C when all pods are up

# test through transparent proxy tunnel (NEGATIVE TEST, should fail)
kubectl exec deploy/static-client -c static-client -- curl -s http://localhost:1234
kubectl exec deploy/static-client -c static-client -- curl -s http://localhost:2234

kubectl apply -f client-to-server-intention.yaml
# test through transparent proxy tunnel (POSITIVE TEST, should succeed)
kubectl exec deploy/static-client -c static-client -- curl -s http://localhost:1234
kubectl exec deploy/static-client -c static-client -- curl -s http://localhost:2234
```
