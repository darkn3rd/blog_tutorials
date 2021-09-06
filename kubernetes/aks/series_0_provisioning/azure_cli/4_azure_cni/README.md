# AKS with Azure CNI

This scenario installed the network plugin Azure CNI, which puts both pods and nodes on the same virtual network.  This potentially dangerous anything running on the same subnet will have direct access pods on the Kubernetes cluster without the need to go through an endpoint, such as an `ingress` or `service`.  As pods and nodes share the same subnet, there's a problem with IP exhaustion, where there will not be enough IP addresses to accomodate both pods and nodes.

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
export AZ_AKS_CLUSTER_NAME=blog-test
export AZ_LOCATION=westus2

export AZ_AKS_IDENTITY_NAME=${AZ_AKS_CLUSTER_NAME}-identity

export AZ_VNET_NAME="${AZ_AKS_CLUSTER_NAME}-vnet"
export AZ_VNET_RANGE="10.0.0.0/8"

export AZ_POD_SUBNET_NAME="${AZ_AKS_CLUSTER_NAME}-pod-subnet"
export AZ_NODE_SUBNET_NAME="${AZ_AKS_CLUSTER_NAME}-node-subnet"
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

az identity create \
  --name ${AZ_AKS_IDENTITY_NAME} \
  --resource-group ${AZ_RESOURCE_GROUP}

export AZ_AKS_IDENTITY_ID=$(az identity show \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_AKS_IDENTITY_NAME} \
  --query id \
  --output tsv
)

## Enable PodSubNet Feature
az feature register --namespace "Microsoft.ContainerService" --name "PodSubnetPreview"
# verify
az feature list --output table \
  --query "[?contains(name, 'Microsoft.ContainerService/PodSubnetPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

az aks create \
    --resource-group ${AZ_RESOURCE_GROUP} \
    --name ${AZ_AKS_CLUSTER_NAME} \
    --generate-ssh-keys \
    --vm-set-type VirtualMachineScaleSets \
    --node-vm-size ${AZ_VM_SIZE:-Standard_DS2_v2} \
    --load-balancer-sku standard \
    --enable-managed-identity \
    --assign-identity $AZ_AKS_IDENTITY_ID \
    --network-plugin "azure" \
    --network-policy "calico" \
    --vnet-subnet-id $NODE_SUBNET_ID \
    --pod-subnet-id $POD_SUBNET_ID \
    --node-count 3 \
    --zones 1 2 3 \
    --max-pods 250

az aks get-credentials \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_AKS_CLUSTER_NAME} \
  --file ${KUBECONFIG}
```

## Verify Results

Afterward, because of the AKS add-on, it will assign `Contributor` role to the resource group assicated with the AKS cluster, and a `Network Contributor` to the node subnet.


```bash
export AZ_AKS_IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_AKS_IDENTITY_NAME} \
  --query clientId \
  --output tsv
)

az role assignment list --assignee $AZ_AKS_IDENTITY_CLIENT_ID --all \
  --query '[].{roleDefinitionName:roleDefinitionName, provider:scope}' \
  --output table | sed 's|/subscriptions.*providers/||' | cut -c -120
```

Example output:

```
RoleDefinitionName    Provider
--------------------  --------------------------------------------------------------------------------------------------
Contributor           /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MC_blog-test_blog-test_westus2
Network Contributor   Microsoft.Network/virtualNetworks/blog-test-vnet/subnets/blog-test-node-subnet
```

## Verifiication

### Verify Kubernetes Cluster

Verify your access to the cluster using `kubectl`

```bash
source env.sh
kubectl get all --all-namespaces
```

## Resources

* [Use managed identities in Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity)
