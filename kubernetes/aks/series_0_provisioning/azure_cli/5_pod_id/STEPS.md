

```bash
############
# STEP 1: enable feature
############################################
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
az feature register --name AutoUpgradePreview --namespace Microsoft.ContainerService
az extension add --name aks-preview
az extension update --name aks-preview
az provider register --namespace Microsoft.ContainerService

############
# STEP 2: create cluster & add feature
############################################
../scripts/create_cluster.sh

az aks update \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --enable-pod-identity

############
# STEP 3: create and associate identity
############################################
IDENTITY_NAME=${AZ_DNS_DOMAIN/./-}-identity

az identity create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${IDENTITY_NAME}

IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query principalId -o tsv)
IDENTITY_CLIENT_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query clientId -o tsv)
IDENTITY_RESOURCE_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query id -o tsv)
AZ_DNS_SCOPE=$(az network dns zone show --name ${AZ_DNS_DOMAIN} --resource-group ${AZ_RESOURCE_GROUP} --query id -o tsv)

az role assignment create \
  --assignee "$IDENTITY_CLIENT_ID" \
  --role "DNS Zone Contributor" \
  --scope "$AZ_DNS_SCOPE"

############
# STEP 4: create pod identity
# This creates resources:
#  * AzureIdentity
#  * AzureIdentityBinding
############################################
POD_IDENTITY_NAMESPACE="kube-addons"
POD_IDENTITY_NAME="external-dns"

az aks pod-identity add \
  --resource-group ${AZ_RESOURCE_GROUP}  \
  --cluster-name ${AZ_CLUSTER_NAME} \
  --namespace ${POD_IDENTITY_NAMESPACE} \
  --name ${POD_IDENTITY_NAME} \
  --identity-resource-id ${IDENTITY_RESOURCE_ID}

############
# STEP 5: deploy external dns
############################################
# podLabels:
#   aadpodidbinding: external-dns
############################################
helmfile apply
