# AKS Cluster with Azure DNS

This small guide demonstrates create the following:

1. Azure DNS Zone
2. Kubernetes cluster (AKS)
3. Allow access to the Azure DNS Zone from K8S nodes

This is especially useful for the addon `external-dns` to automatically update DNS records when a load balancer is created through `service` or `ingress` resources, or for the addon `cert-manager` that needs to verify using DNS.

## **SECURITY WARNING**

This procedure will attach a role to the managed identity called *kubelet identity*, which is essentially the service principal created for a node pool.  This allow **ALL** pods running on the cluster to have priviledges to the resource.

Depending on the service, this can be dangerous and inappropriate as it violates the principal of least priviledge.  For exapmle, for ACR (Azure Container Registry) where **ALL** pods **NEED** to pull images from the service, this would be an appropriate configuration.  

For a CI/CD solution that would push images to the ACR service, this would NOT appropriate, and should be restricted at the pod level using pod identity.  Modifying DNS records, such as services running on `external-dns` and `cert-manager` pods, also falls into this category, and this method is not appropriate.

For demonstration purposes ONLY, this guide shows how to use *kubelet identity* with Azure DNS service.  This is used as a learning exercise to learn how:

* use the External DNS service on AKD with Azure DNS
* configure security privileges on a managed identity for the whole cluster (kubelet identity)


## Overview

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
export AZ_DNS_RESOURCE_GROUP=basic-dns
export AZ_DNS_LOCATION=westus2

export AZ_AKS_RESOURCE_GROUP=basic-aks
export AZ_AKS_LOCATION=westus2
export AZ_AKS_CLUSTER_NAME=basic-aks

export AZ_DNS_DOMAIN=example.internal
export KUBECONFIG=~/.kube/AZ_AKS_LOCATION_$AZ_AKS_CLUSTER_NAME
EOF
```

### Create Azure Resources

```bash
source env.sh

../scripts/create_cluster.sh
../scripts/create_dns_zone.sh

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
AKS_SP_ID=$(az aks show -g $AZ_AKS_RESOURCE_GROUP -n $AZ_AKS_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" -o tsv)

# list roles assigned to a provider (truncated string of the full scope)
# NOTE: This assumes all resources are in the same resource group and
#       subscription as the AKS cluster
az role assignment list --assignee $AKS_SP_ID --all \
  --query '[].{roleDefinitionName:roleDefinitionName, provider:scope}' \
  --output table | sed 's|/subscriptions.*providers/||' | cut -c -80
```

### Example: External DNS

You can install `external-dns` using helmfile script that contains `helm` deployment instructions and values.

```bash
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
pushd examples/externaldns/ && helmfile apply && popd
```

For a demo application that uses `external-dns`, you deploy this small `hello-kubernetes` demo application:

```bash
pushd ../demos/external-dns/hello-kubernetes/ && helmfile apply && popd
```

Give this a little while, then test the results with

```bash
curl hello.$AZ_DNS_DOMAIN
```

### Cleanup

* Deleting only `hello-kubernetes` demo
  ```bash
  helm delete -n hello hello-kubernetes
  ```
* Deleting only `external-dns` addon
  ```bash
  helm delete -n kube-addons external-dns
  ```
* Delete entire AKS Cluster
  ```bash
  ../scripts/delete_cluster.sh
  ```
