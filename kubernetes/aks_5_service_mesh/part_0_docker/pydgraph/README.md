# Pydgraph Client

This is small utility container that can execute seed the graph database with a schema and data (RDF n-quads).  This process only documents building and pushing the artifact to a container registry.


## Building

```bash
az acr login --name ${AZ_ACR_NAME}

make build
make push

# verify results
az acr repository list --name ${AZ_ACR_NAME} --output table
```
