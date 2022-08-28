DG_ALLOW_LIST=$(az aks show \
  --name $AZ_CLUSTER_NAME \
  --resource-group $AZ_RESOURCE_GROUP | \
  jq -r '.networkProfile.podCidr,.networkProfile.serviceCidr' | \
  tr '\n' ','
)
MY_IP_ADDRESS=$(curl --silent ifconfig.me)
export DG_ALLOW_LIST="${DG_ALLOW_LIST}${MY_IP_ADDRESS}/32"
