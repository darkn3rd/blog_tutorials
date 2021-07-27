# Build-Push Container Image to ACR

## Create env.sh file

```bash
cat <<-EOF > env.sh
# resource group
export AZ_RESOURCE_GROUP=netpolmesh-test
export AZ_LOCATION=westus2

# container registry
export AZ_ACR_NAME=netpolmeshtest
EOF
```

## Create an container registry

```bash
source env.sh

############
# create Azure Container Registry
############################################
az acr create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_ACR_NAME} \
  --sku Basic

az acr login --name ${AZ_ACR_NAME}

# Add docker registry name so that this can be used later
cat <<-'EOF' >> env.sh
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)
EOF
```

## Build and push the image

See [pydgraph/README.md](pydgraph/README.md)

## Links

* [Tutorial: Deploy and use Azure Container Registry](https://docs.microsoft.com/azure/aks/tutorial-kubernetes-prepare-acr)
