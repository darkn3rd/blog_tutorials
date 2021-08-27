IDENTITY_NAME=${AZ_DNS_DOMAIN/./-}
export IDENTITY_RESOURCE_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query clientId -o tsv)
export IDENTITY_RESOURCE_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query id -o tsv)
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

POD_IDENTITY_NAMESPACE="kube-addons"
POD_IDENTITY_NAME="external-dns"

az aks pod-identity add \
  --resource-group ${AZ_RESOURCE_GROUP}  \
  --cluster-name ${AZ_CLUSTER_NAME} \
  --namespace ${POD_IDENTITY_NAMESPACE} \
  --name ${POD_IDENTITY_NAME} \
  --identity-resource-id ${IDENTITY_RESOURCE_ID}
