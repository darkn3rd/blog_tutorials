# Build-Push Container Image to ACR

These are instructions for building and pushing container images to ACR that can be used with service mesh projects.

Container Projects:

* [AKS SSH](./aks_ssh/README.md) - ssh utility to access AKS nodes
* [Pydgraph Client](./pydgraph/README.md) - build/push `pydgraph-client` images
* [Linkerd Images](./linkerd/README.md) - republish `linkerd` images to ACR

## Requirements

* [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
* [docker](https://docs.docker.com/get-docker/) - build/push images to ACR

## Create env.sh file

```bash
cat <<-EOF > acr_env.sh
# resource group
export AZ_RESOURCE_GROUP=netpolmesh-test
export AZ_LOCATION=westus2

# resource group for ACR (change if different)
export AZ_ACR_RESOURCE_GROUP=$AZ_RESOURCE_GROUP

# container registry
export AZ_ACR_NAME=netpolmeshtest
EOF
```

The resource group(s) should already have been created.

## Create an container registry

```bash
source acr_env.sh

############
# create Azure Container Registry
############################################
az acr create \
  --resource-group ${AZ_ACR_RESOURCE_GROUP} \
  --name ${AZ_ACR_NAME} \
  --sku Basic

az acr login --name ${AZ_ACR_NAME}

############
# reference ACR server for pushing images or deploys using those images
############################################
cat <<-'EOF' >> env.sh
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_ACR_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)
EOF
```

# Links

* [Tutorial: Deploy and use Azure Container Registry](https://docs.microsoft.com/azure/aks/tutorial-kubernetes-prepare-acr)
