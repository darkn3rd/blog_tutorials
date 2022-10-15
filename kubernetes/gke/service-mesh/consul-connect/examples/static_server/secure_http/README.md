# Secure HTTP Server

These are examples from the tutorials using the static server application.

# Consul service mesh install

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com && helm repo update

# Delete namespace if it exists
kubectl delete namespace consul

helm install consul hashicorp/consul \
  --values dc1.yaml \
  --create-namespace \
  --namespace consul \
  --version "0.43.0" \
  --wait

helm upgrade consul hashicorp/consul \
  --namespace consul \
  --version "0.43.0" \
  --values ./secure-dc1.yaml \
  --wait
```

# Test

```bash
kubectl apply -f server.yaml
kubectl apply -f client.yaml
watch kubectl get pods # CTRL-C when all pods are up

# test through transparent proxy tunnel (NEGATIVE TEST, should fail)
kubectl exec deploy/static-client -c static-client -- curl -s http://static-server
kubectl apply -f client-to-server-intention.yaml
# test through transparent proxy tunnel (POSITIVE TEST, should succeed)
kubectl exec deploy/static-client -c static-client -- curl -s http://static-server
```

# References

This is based on this tutorial on 2022-10-08:

* [Secure Consul and Registered Services on Kubernetes](https://learn.hashicorp.com/tutorials/consul/kubernetes-secure-agents)
