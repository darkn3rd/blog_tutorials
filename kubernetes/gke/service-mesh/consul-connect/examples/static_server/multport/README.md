# Multiport

This is a multi-port example from Hashicorp's documentation.

## Deploy
```bash
kubectl apply -f server.yaml
kubectl apply -f client.yaml
kubectl exec -it static-client-5bd667fbd6-kk6xs -- /bin/sh
```

## Exec into Pod

```bash
export NS=${NS:-"default"}
POD=$(kubectl get pods --namespace $NS --selector app=static-client --output name)
kubectl exec -ti --container "static-client" --namespace $NS ${POD} -- /bin/sh
```

## Test

```bash
# connect through mesh tunnel
curl localhost:1234
curl localhost:2234

# connect directly to service port (outside of mesh tunnel)
# NOTE: These are K8S DNS names for service resource. With transparent-proxy
# turned off, this will go directly to the application container and bypass the
# service mesh altogether.  This is not a desirable outcome but this is how
# it works.
export NS=${NS:-"default"}
curl web.$NS.svc.cluster.local
curl web-admin.$NS.svc.cluster.local
```


## Resources

* [Kubernetes Pods with Multiple ports](https://www.consul.io/docs/k8s/connect#kubernetes-pods-with-multiple-ports)
