
# export AZ_DNS_DOMAIN="arrakis.internal"
IDENTITY_NAME=${AZ_DNS_DOMAIN/./-}
export IDENTITY_CLIENT_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query clientId -o tsv)
export IDENTITY_RESOURCE_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query id -o tsv)
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

