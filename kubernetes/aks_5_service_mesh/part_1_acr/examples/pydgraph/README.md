# Pydgraph Client Deploy

This is small utility container that can execute seed the graph database with a schema and data (RDF n-quads).  The container image should be accessible online by the AKS cluster.

## Deploy

You can use `helmfile` or `envsubt` to the `deploy pydgraph-client` utility/

### Method A: Using Helmfile

This requires [`helmfile`](https://github.com/roboll/helmfile) utility.

```bash
## extract loginserver name w/ JMESPath query
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)

helmfile apply
```

### Method B: Using kubectl with envsubst

This will require the `envsubst` tool.

NOTE: If you have macOS, this tool is not available. If you have [Homebrew](https://brew.sh/), you get this tool with: `brew install gettext`.  Run the command `brew info gettext` for further info.

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

## Running tools in client the pydgraph-client container

Use these commands to log into the container:

```bash
PYDGRAPH_POD=$(kubectl get pods --namespace pydgraph-client --output name)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} -- bash
```

### grpcurl

Log into the container, then run this command to test gRPC with `grpcurl`:

```bash
grpcurl -plaintext -proto api.proto ${DGRAPH_ALPHA_SERVER}:9080 api.Dgraph/CheckVersion
```

### getting_started_data.py

Log into the container, then run this command to load the schema and rdf data into Dgraph:

```bash
python3 load_data.py --plaintext \
  --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema sw.schema
```

### Run a query

Log into the container, then run these commands to run queries.  The data and schema must have been already loaded into Dgraph before running this commands.

#### Query all movies

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
```

#### Query all movies after 1980

```bash
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
