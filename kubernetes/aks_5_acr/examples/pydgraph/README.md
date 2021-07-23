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


### grpcurl

```bash
DGRAPH_ALPHA_SERVER=<alpha>
grpcurl --insecure -proto api.proto ${DGRAPH_ALPHA_SERVER} api.Dgraph/CheckVersion
```

### getting_started_data.py

```bash
DGRAPH_ALPHA_SERVER=<alpha>
./load_data.py --insecure \
  --alpha ${DGRAPH_ALPHA_SERVER} \
  --files ./sw.nquads.rdf \
  --schema sw.schema
```

### run a query
