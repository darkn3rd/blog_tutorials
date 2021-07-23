

* https://docs.microsoft.com/azure/aks/tutorial-kubernetes-prepare-acr
* https://docs.microsoft.com/azure/aks/cluster-container-registry-integration



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

```bash
docker tag mcr.microsoft.com/azuredocs/azure-vote-front:v1 $AZ_ACR_LOGIN_SERVER/azure-vote-front:v1
az acr repository list --name $AZ_ACR_NAME --output table
```
