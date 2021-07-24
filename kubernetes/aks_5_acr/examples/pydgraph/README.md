# Pydgraph Client

This is small utility container that can execute seed the graph database with a schema and data (RDF n-quads).


## Building

```bash
az acr login --name ${AZ_ACR_NAME}

make build
make push

# verify results
az acr repository list --name ${AZ_ACR_NAME} --output table
```

## Deploy

### Using Helmfile

```bash
## extract loginserver name w/ JMESPath query
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)

helmfile apply
```

### Using kubectl with envsubst

```bash
## extract loginserver name w/ JMESPath query
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)

kubectl create namepsace pydgraph-client
envsubst < deploy.yaml.envsubst | kubectl --namespace pydraph-client --filename -
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
