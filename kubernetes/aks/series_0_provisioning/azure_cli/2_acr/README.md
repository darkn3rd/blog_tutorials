# Basic AKS with ACR support

This will create a basic HA cluster with three nodes (one node per zone) and support for a private container registry with ACR.


This is a basic HA cluster with three nodes, one node per zone.

This cluster will have the following details:

* AKS (Kubernetes)
  * Kubernetes version: latest per region (v1.20.7 for `westus2` on 2021-Aug-21)
  * Network Plugin: `kubenet`
  * Network Policy: none
  * Max Pods for Cluster: 250
    * Max Pods per Node: 110
  * Azure Resoruces:
    * Load Balancer (Standard)
    * Public IP
    * Network Security Group
    * VMSS with 3 worker nodes
    * Managed Identity for the worker nodes
      * AcrPull role added
    * Virtual Network
    * Routes
      * route to pod overlay networks on the Nodes


* https://joachim8675309.medium.com/azure-kubernetes-service-b89cc52b7f02

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes

## Instructions

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=blog-test
export AZ_CLUSTER_NAME=blog-test
export AZ_LOCATION=westus2
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME.yaml
EOF

source env.sh
./scripts/create_acr.sh
./scripts/create_cluster.sh
```

## Verifiication

### Verify Kubernetes Cluster

Verify your access to the cluster using `kubectl`

```bash
source env.sh
kubectl get all --all-namespaces
```

### Verify Access to ACR

Verify the the nodepool workers have access.  Specifically, a Managed Identity that is assigned to VMSS for the agentpool as the AcrPull role definition for the ACR that was created.

```bash
source env.sh
# fetch object id of managed identity installed for VMSS node group
AKS_SP_ID=$(az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" -o tsv)

# list roles assigned to a provider (truncated string of the full scope)
# NOTE: This assumes all resources are in the same resource group and
#       subscription as the AKS cluster
az role assignment list --assignee $AKS_SP_ID --all \
  --query '[].{roleDefinitionName:roleDefinitionName, provider:scope}' \
  --output table | sed 's|/subscriptions.*providers/||' | cut -c -80
```

## Resources

* [Network concepts for applications in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/concepts-network)
* [List Azure role assignments using Azure CLI](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-list-cli)
