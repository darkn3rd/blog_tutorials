# AKS with Azure CNI

This scenario installed the network plugin Azure CNI, which puts both pods and nodes on the same virtual network.  This potentially dangerous anything running on the same subnet will have direct access pods on the Kubernetes cluster without the need to go through an endpoint, such as an `ingress` or `service`.

In order to ameliorate this risk while still using Azure CNI, one method place the nodes and pods on different virutal networks.

## Blogs Using this Content

*  none

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes

## Instructions

### Create Environment Configuration

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=blog-test
export AZ_CLUSTER_NAME=blog-test
export AZ_LOCATION=westus2

export AZ_VNET_NAME="${AKS_CLUSTER_NAME}-vnet"
export AZ_VNET_RANGE="10.0.0.0/8"

export AZ_POD_SUBNET_NAME="${AKS_CLUSTER_NAME}-pod-subnet"
export AZ_NODE_SUBNET_NAME="${AKS_CLUSTER_NAME}-node-subnet"
export AZ_POD_SUBNET_RANGE="10.242.0.0/16"
export AZ_NODE_SUBNET_RANGE="10.243.0.0/16"

EOF
```

### Create VirtualNetworks

```bash
source env.sh

az network vnet create \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_VNET_NAME \
  --address-prefixes $AZ_VNET_RANGE \
  --output none

# TODO: are UDRs needed? or automatically created?
az network vnet subnet create \
  --resource-group $AZ_RESOURCE_GROUP \
  --vnet-name $AZ_VNET_NAME \
  --name $AZ_POD_SUBNET_NAME \
  --address-prefixes $AZ_POD_SUBNET_RANGE \
  --output none
az network vnet subnet create \
  --resource-group $AZ_RESOURCE_GROUP \
  --vnet-name $AZ_VNET_NAME \
  --name $AZ_NODE_SUBNET_NAME \
  --address-prefixes $AZ_NODE_SUBNET_RANGE \
  --output none
```

### Create Cluster

```bash
source env.sh

POD_SUBNET_ID=$(az network vnet subnet show \
  --resource-group $AZ_RESOURCE_GROUP \
  --vnet-name $AZ_VNET_NAME \
  --name $AZ_POD_SUBNET_NAME \
  --query id \
  --output tsv
)

NODE_SUBNET_ID=$(az network vnet subnet show \
  --resource-group $AZ_RESOURCE_GROUP \
  --vnet-name $AZ_VNET_NAME \
  --name $AZ_NODE_SUBNET_NAME \
  --query id \
  --output tsv
)

# TODO: PodSubnetPreview required for pod-subnet?
az aks create \
    --resource-group ${AZ_RESOURCE_GROUP} \
    --name ${AZ_CLUSTER_NAME} \
    --generate-ssh-keys \
    --vm-set-type VirtualMachineScaleSets \
    --node-vm-size ${AZ_VM_SIZE} \
    --load-balancer-sku standard \
    --enable-managed-identity \
    --network-plugin "azure" \
    --network-policy "calico" \
    --vnet-subnet-id $NODE_SUBNET_ID \
    --pod-subnet-id $POD_SUBNET_ID    
    --node-count 3 \
    --zones 1 2 3 \
    --max-pods 250
```

## Verifiication

### Verify Kubernetes Cluster

Verify your access to the cluster using `kubectl`

```bash
source env.sh
kubectl get all --all-namespaces
```
