
kubectl create namespace $K8S_NAMESPACE

## Create Resource Group
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_AKS_RESOURCE_GROUP}; then
  az group create --name=${AZ_AKS_RESOURCE_GROUP} --location=${AZ_AKS_LOCATION}
fi

## Create Cluster
az aks create \
  --resource-group ${AZ_AKS_RESOURCE_GROUP} \
  --name ${AZ_AKS_CLUSTER_NAME} \
  --generate-ssh-keys \
  --vm-set-type VirtualMachineScaleSets \
  --node-vm-size ${AZ_AKS_VM_SIZE:-Standard_DS2_v2} \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --node-count 3 \
  --zones 1 2 3

az aks get-credentials \
  --resource-group ${AZ_AKS_RESOURCE_GROUP} \
  --name ${AZ_AKS_CLUSTER_NAME} \
  --file ${KUBECONFIG}

################################
# AUTHORIZATION TO KUBLET ID
################################

# fetch information using JMESPath query
AZ_DNS_SCOPE=$(
  az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].id" --output tsv
)

# fetch kublet id
AZ_AKS_PRINCIPAL_ID=$(
  az aks show -g $AZ_AKS_RESOURCE_GROUP -n $AZ_AKS_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" --output tsv
)

az role assignment create \
  --assignee "$AZ_AKS_PRINCIPAL_ID" \
  --role "DNS Zone Contributor" \
  --scope "$AZ_DNS_SCOPE"

################################
# CREATE SECRET
################################
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

cat <<-EOF > azure.json
{
  "tenantId": "$AZ_TENANT_ID",
  "subscriptionId": "$AZ_SUBSCRIPTION_ID",
  "resourceGroup": "$AZ_DNS_RESOURCE_GROUP",
  "useManagedIdentityExtension": true,
}
EOF

kubectl create secret generic azure-config-file --from-file=azure.json --namespace $K8S_NAMESPACE

kc apply -f rbac_cluster.yaml -n $K8S_NAMESPACE
