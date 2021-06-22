# Dgraph

## Dgraph with Helmfile

```bash
. env.sh
pushd examples/dgraph

## Build Accept List
DG_ACCEPT_LIST=$(az aks show \
  --name $AZ_CLUSTER_NAME \
  --resource-group $AZ_RESOURCE_GROUP | \
  jq -r '.networkProfile.podCidr,.networkProfile.serviceCidr' | \
  tr '\n' ','
)
# append home office IP address
MY_IP_ADDRESS=$(curl --silent ifconfig.me)
DG_ACCEPT_LIST="${DG_ACCEPT_LIST}${MY_IP_ADDRESS}/32"
export DG_ACCEPT_LIST

# Deploy
helmfile apply
popd
```
