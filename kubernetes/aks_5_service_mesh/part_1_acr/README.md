# AKS with ACR registry integration

## Create env.sh file

```bash
cat <<-EOF > env.sh
# resource group
export AZ_RESOURCE_GROUP=acr-test
export AZ_LOCATION=westus2

# container registry
export AZ_ACR_NAME=acrtest
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)

# kubernetes cluster
export AZ_CLUSTER_NAME=acr-test
export AZ_LOCATION=westus2
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml
EOF
```

## Create an container registry

The container registry should have been created in a previous step. See [part_0_docker/README.md](../part_0_docker/README.md)

## Provision AKS Cluster

```bash
source env.sh
bash scripts/create_aks_.sh
```

## Deploy Dgraph database

See [examples/dgraph/README.md](examples/dgraph/README.md)

## Build and push an pydgraph image

See [../part_0_docker/pydgraph/README.md](part_0_docker/pydgraph/README.md)

## Deploy pydgraph container

See [examples/pydgraph/README.md](examples/pydgraph/README.md)

## Links

* [Authenticate with Azure Container Registry from Azure Kubernetes Service](https://docs.microsoft.com/azure/aks/cluster-container-registry-integration)
