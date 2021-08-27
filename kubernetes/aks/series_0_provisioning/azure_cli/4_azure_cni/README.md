# AKS using Azure CNI network plugin with separate Pod VNET

This scenario will create a HA Kubernetes cluster with Pods placed on a separate network from the Nodes.  

With Azure CNI, pods are placed on Azure VNET that is used by the Nodes.  This introduces potential security issues as pods can be directly accessed by VMs on the same subnet, and issues where IP addresses can get exhausted when assigned to both pods and nodes.


## FROM AZURE CNI ARTICLE

``` bash
az network vnet subnet list \
    --resource-group $AZ_RESOURCE_GROUP \
    --vnet-name $AZ_VNET \
    --query "[0].id" --output tsv


az aks create \
    --resource-group $AZ_RESOURCE_GROUP \
    --name myAKSCluster \
    --network-plugin azure \
    --vnet-subnet-id <subnet-id> \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --generate-ssh-keys
```

### Dynamic IP allocation

```bash
az feature register --namespace "Microsoft.ContainerService" --name "PodSubnetPreview"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/PodSubnetPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService
```

#### Dynamic allocation of IPs and enhanced subnet support

```bash
AZ_RESOURCE_GROUP="myResourceGroup"
AZ_VNET="myVirtualNetwork"
AZ_LOCATION="westcentralus"

# Create the resource group
az group create --name $AZ_RESOURCE_GROUP --location $AZ_LOCATION

# Create our two subnet network
az network vnet create -g $AZ_RESOURCE_GROUP --location $AZ_LOCATION --name $AZ_VNET --address-prefixes 10.0.0.0/8 -o none
az network vnet subnet create -g $AZ_RESOURCE_GROUP --vnet-name $AZ_VNET --name nodesubnet --address-prefixes 10.240.0.0/16 -o none
az network vnet subnet create -g $AZ_RESOURCE_GROUP --vnet-name $AZ_VNET --name podsubnet --address-prefixes 10.241.0.0/16 -o none

export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')
GROUP_PATH="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP"
NODE_SUBNET_ID="$GROUP_PATH/providers/Microsoft.Network/virtualNetworks/$AZ_VNET/subnets/nodesubnet"
POD_SUBNET_ID="$GROUP_PATH/providers/Microsoft.Network/virtualNetworks/$AZ_VNET/subnets/podsubnet"

az aks create -n $AZ_CLUSTER_NAME -g $AZ_RESOURCE_GROUP -l $AZ_LOCATION \
  --max-pods 250 \
  --node-count 2 \
  --network-plugin azure \
  --vnet-subnet-id $NODE_SUBNET_ID \
  --pod-subnet-id $POD_SUBNET_ID
```

#### Adding node pool

```bash
az network vnet subnet create -g $AZ_RESOURCE_GROUP --vnet-name $AZ_VNET --name "node2subnet" --address-prefixes 10.242.0.0/16 -o none
az network vnet subnet create -g $AZ_RESOURCE_GROUP --vnet-name $AZ_VNET --name "pod2subnet" --address-prefixes 10.243.0.0/16 -o none

export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')
GROUP_PATH="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP"
NODE2_SUBNET_ID="$GROUP_PATH/providers/Microsoft.Network/virtualNetworks/$AZ_VNET/subnets/node2subnet"
POD2_SUBNET_ID="$GROUP_PATH/providers/Microsoft.Network/virtualNetworks/$AZ_VNET/subnets/pod2subnet"

az aks nodepool add --cluster-name $AZ_CLUSTER_NAME -g $AZ_RESOURCE_GROUP  -n "newnodepool" \
  --max-pods 250 \
  --node-count 2 \
  --vnet-subnet-id $NODE2_SUBNET_ID \
  --pod-subnet-id $POD2_SUBNET_ID \
  --no-wait
```
