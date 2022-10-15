# Deploying Dgraph

```bash
helmfile apply
```


These needs to be added to Zero and Alpha STS:

```yaml
spec.template.metadata.annotations:
  consul.hashicorp.com/connect-inject: "true"
  consul.hashicorp.com/transparent-proxy: "true"
```

These need to be added to headless SVCs for Alpha and Zero:

```yaml
metadata.labels:
  consul.hashicorp.com/service-ignore: 'true'
```


# Pydgraph Client

```bash
export CCSM_ENABLED
helmfile --file pydgraph_client.yaml apply
```

```bash
CLIENT_NS="pydgraph-client"
PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NS --output name)
kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NS \
  ${PYDGRAPH_POD} -- bash
```

```bash
curl --silent localhost:8080/health
grpcurl -plaintext -proto api.proto localhost:9080 api.Dgraph/CheckVersion
```
