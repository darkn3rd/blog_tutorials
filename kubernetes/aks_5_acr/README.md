# AKS with ACR registry integration

## Create an container registry

```bash
. env

############
# create Azure Container Registry
############################################
az acr create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_ACR_NAME} \
  --sku Basic

az acr login --name ${AZ_ACR_NAME}

## extract loginserver name w/ JMESPath query
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)
```

## Build and push an image

```bash
az acr login --name ${AZ_ACR_NAME}
make build
make push
az acr repository list --name $AZ_ACR_NAME --output table
```

## Links

* [Tutorial: Deploy and use Azure Container Registry](https://docs.microsoft.com/azure/aks/tutorial-kubernetes-prepare-acr)
* [Authenticate with Azure Container Registry from Azure Kubernetes Service](https://docs.microsoft.com/azure/aks/cluster-container-registry-integration)
