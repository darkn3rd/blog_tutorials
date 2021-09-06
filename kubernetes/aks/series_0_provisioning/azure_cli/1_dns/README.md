# AKS Cluster with Azure DNS

This small guide demonstrates create the following:

1. Azure DNS Zone
2. Kubernetes cluster (AKS)
3. Allow access to the Azure DNS Zone from K8S nodes

This is especially useful for the addon `external-dns` to automatically update DNS records when a load balancer is created through `service` or `ingress` resources, or for the addon `cert-manager` that needs to verify using DNS.

**NOTE**: This procedure will attach a role to the managed identity, or a service principal created for a node pool, will allow all pods in the cluster to priviledges to the resource.  Depending on the servcie, this is inappropriate and violates principal of least priviledge. For pulling images from ACR, this would be an appropriate use case, but for updating DNS records, this should be limited to the services that need it, such as `external-dns` and `cert-manager`.  For more granular security required for production environments, use Pod identities.

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
    * VMSS with 3 worker nodes (1 node per zone)
      * Managed Identity for the worker nodes
        * DNS contributor role added
    * Virtual Network
    * Routes
      * route to pod overlay networks on the Nodes

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
export AZ_DNS_DOMAIN="example.internal"
export KUBECONFIG=~/.kube/$AZ_AKS_CLUSTER_NAME
EOF
```

### Create Azure Resources

```bash
source env.sh

../script/create_cluster.sh
../script/cerate_dns.sh

# allow access to DNS zone from AKS nodes
./attach_dns.sh
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
AKS_SP_ID=$(az aks show -g $AZ_RESOURCE_GROUP -n $AZ_AKS_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" -o tsv)

# list roles assigned to a provider (truncated string of the full scope)
# NOTE: This assumes all resources are in the same resource group and
#       subscription as the AKS cluster
az role assignment list --assignee $AKS_SP_ID --all \
  --query '[].{roleDefinitionName:roleDefinitionName, provider:scope}' \
  --output table | sed 's|/subscriptions.*providers/||' | cut -c -80
```
