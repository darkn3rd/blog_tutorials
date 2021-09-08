# Basic AKS with Terraform

# Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [terraform](https://www.terraform.io/) - provisioning tool to create cloud resources

## Azure Subscription

An account needs to be registered to create an Azure subscripiton, and then after installing `az`, run:

```bash
az login
```

# Steps

## Create tf vars defaults

```bash
cat <<-EOF >> $TF_VARS
resource_group_name = "aks-basic-tf"
location            = "westus2"

cluster_name        = "basic"
dns_prefix          = "basic"
EOF
```

## Provision AKS Cluster

The `--target` (or `-target`) is required because modules do not support dependency mechanism. The resource group will need to be created first, before creating AKS.

```bash
# create resource group if it does not already exists
AZ_RESOURCE_GROUP=$(awk -F'"' '/resource_group_name/{ print $2 }' terraform.tfvars)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_RESOURCE_GROUP}; then
  terraform apply --target "module.rg" --var create_group="true"
fi

# create the AKS cluster
terraform apply
```

## Credentials for Kubectl

```bash
export AZ_CLUSTER_NAME="$(terraform output -raw kubernetes_cluster_name)"
export AZ_RESOURCE_GROUP="$(terraform output -raw resource_group_name)"
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml

az aks get-credentials \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_CLUSTER_NAME \
  --file $KUBECONFIG
```

## Verify

```bash
kubectl get all --all-namespaces
```

## Explore Networking

You can view the IP addresses used by nodes and pods with the following commands:

```bash
JSONPATH_NODES='{range .items[*]}{@.metadata.name}{"\t"}{@.status.addresses[?(@.type == "InternalIP")].address}{"\n"}{end}'
JSONPATH_PODS='{range .items[*]}{@.metadata.name}{"\t"}{@.status.podIP}{"\n"}{end}'

cat <<-EOF
Nodes:
------------
$(kubectl get nodes --output jsonpath="$JSONPATH_NODES" | xargs printf "%-40s %s\n")

Pods:
------------
$(kubectl get pods --output jsonpath="$JSONPATH_PODS" --all-namespaces | \
    xargs printf "%-40s %s\n"
)
EOF
```

## Demo: hello-kubernetes

See [demos/hello-kubernetes/README.md](../demos/hello-kubernetes/README.md)

## Explore Routing

Assuming the default `kubenet` plug-in is used, you can view the routes created with the following command:

```bash
AZ_RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AZ_LOCATION=$(terraform output -raw resource_group_location)
AZ_AKS_CLUSTER_NAME=$(terraform output -raw kubernetes_cluster_name)

az network route-table list \
  --resource-group MC_${AZ_RESOURCE_GROUP}_${AZ_AKS_CLUSTER_NAME}_${AZ_LOCATION} \
  --query '[].routes[].{Name:name,"Address Prefix":addressPrefix,"Next hop IP address":nextHopIpAddress}' \
  --output table
```

# Cleanup

```bash
terraform destroy
```

# Links

* [Creating a Kubernetes Cluster with AKS and Terraform](https://www.hashicorp.com/blog/kubernetes-cluster-with-aks-and-terraform) on May 23 2018 by Nic Jackson - this article has not been updated and example code is Terraform v0.11 or earlier.
* [Provision an AKS Cluster (Azure)](https://learn.hashicorp.com/tutorials/terraform/aks)
  * Source Code: https://github.com/hashicorp/learn-terraform-provision-aks-cluster
* [Getting started with Terraform and Kubernetes on Azure AKS](https://learnk8s.io/terraform-aks)
* [Create a Kubernetes cluster with Azure Kubernetes Service using Terraform](https://docs.microsoft.com/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks) on Aug 07, 2021 - this article covers using Azure storage for maintaining state, and using Container Insights as well as basic Azure.
