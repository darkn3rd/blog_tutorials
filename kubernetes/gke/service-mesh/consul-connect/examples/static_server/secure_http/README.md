# Secure HTTP Server



# Consul service mesh install

```bash
helm upgrade install hashicorp/consul \
  --namespace consul\
  --version "0.43.0" \
  --values ./secure-dc1.yaml \
  --wait
```

# Test

```bash
kubectl apply -f server.yaml
kubectl apply -f client.yaml
watch kubectl get pods
kubectl exec deploy/static-client -c static-client -- curl -s http://static-server
kubectl apply -f client-to-server-intention.yaml
kubectl exec deploy/static-client -c static-client -- curl -s http://static-server
```

# References

This is based on this tutorial on 2022-10-08:

* [Secure Consul and Registered Services on Kubernetes](https://learn.hashicorp.com/tutorials/consul/kubernetes-secure-agents)
