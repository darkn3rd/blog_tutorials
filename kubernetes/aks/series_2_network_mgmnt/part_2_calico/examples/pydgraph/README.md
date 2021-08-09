# Dgraph Deploy

## Deploy

### Using Helmfile

```bash
./deploy_pydgraph_client.sh
```

## Verify

You can check to see if the pod is deployed:

```bash
kubectl get all --namespace pydgraph-client
```

## Running Tools in Client Container

```bash
PYDGRAPH_POD=$(kubectl get pods --namespace pydgraph-client --output name)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} --container "pydgraph-client" -- bash
```

## Running Tools in Client Container

```bash
PYDGRAPH_POD=$(kubectl get pods --namespace pydgraph-client --output name)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} -- bash
```

### grpcurl

```bash
grpcurl -plaintext -proto api.proto ${DGRAPH_ALPHA_SERVER}:9080 api.Dgraph/CheckVersion
```

### getting_started_data.py

```bash
python3 load_data.py --plaintext \
  --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema sw.schema
```

### run a query

```bash
curl "${DGRAPH_ALPHA_SERVER}:8080/query" --silent --request POST \
  --header "Content-Type: application/dql" \
  --data $'
{
 me(func: has(starring)) {
   name
  }
}
' | jq

curl "${DGRAPH_ALPHA_SERVER}:8080/query" --silent --request POST \
  --header "Content-Type: application/dql" \
  --data $'
{
  me(func: allofterms(name, "Star Wars"), orderasc: release_date) @filter(ge(release_date, "1980")) {
    name
    release_date
    revenue
    running_time
    director {
     name
    }
    starring (orderasc: name) {
     name
    }
  }
}
' | jq
