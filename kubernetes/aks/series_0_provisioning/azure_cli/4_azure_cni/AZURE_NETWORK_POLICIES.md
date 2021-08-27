03/16/2021

# Azure CNI for Network Plugin and Network Policy

## Network Infra

```bash
AZ_RESOURCE_GROUP=myResourceGroup-NP
AZ_CLUSTER_NAME=myAKSCluster
AZ_LOCATION=canadaeast
AZ_VNET="myVnet"
AZ_SUBNET_NAME="myAKSSubnet"

# Create a resource group
az group create --name $AZ_RESOURCE_GROUP --location $AZ_LOCATION

# Create a virtual network and subnet
az network vnet create \
    --resource-group $AZ_RESOURCE_GROUP \
    --name $AZ_VNET \
    --address-prefixes 10.0.0.0/8 \
    --subnet-name $AZ_SUBNET_NAME \
    --subnet-prefix 10.240.0.0/16

# Create a service principal and read in the application ID
SP=$(az ad sp create-for-rbac --output json)
SP_ID=$(echo $SP | jq -r .appId)
SP_PASSWORD=$(echo $SP | jq -r .password)

# Wait 15 seconds to make sure that service principal has propagated
echo "Waiting for service principal to propagate..."
sleep 15

# Get the virtual network resource ID
AZ_VNET_ID=$(az network vnet show --resource-group $AZ_RESOURCE_GROUP --name $AZ_VNET --query id -o tsv)

# Assign the service principal Contributor permissions to the virtual network resource
az role assignment create --assignee $SP_ID --scope $AZ_VNET_ID --role Contributor

# Get the virtual network subnet resource ID
AZ_SUBNET_ID=$(az network vnet subnet show --resource-group $AZ_RESOURCE_GROUP --vnet-name $AZ_VNET --name $AZ_SUBNET_NAME --query id -o tsv)
```

## CLUSTER

```bash
az aks create \
    --resource-group $AZ_RESOURCE_GROUP \
    --name $AZ_CLUSTER_NAME \
    --node-count 1 \
    --generate-ssh-keys \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $AZ_SUBNET_ID \
    --service-principal $SP_ID \
    --client-secret $SP_PASSWORD \
    --network-plugin azure \
    --network-policy azure
```

## Calico Policy

```bash
az aks create \
    --resource-group $AZ_RESOURCE_GROUP \
    --name $AZ_CLUSTER_NAME \
    --node-count 1 \
    --generate-ssh-keys \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $AZ_SUBNET_ID \
    --service-principal $SP_ID \
    --client-secret $SP_PASSWORD \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --network-policy calico
```