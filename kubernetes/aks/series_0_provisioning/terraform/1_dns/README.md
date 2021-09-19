# AKS with (External-DNS)

# Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [terraform](https://www.terraform.io/) - provisioning tool to create cloud resources

## Azure Subscription

An account needs to be registered to create an Azure subscripiton, and then after installing `az`, run:

```bash
az login
```

## Domain Name

You can use the following:

* create a prviate domain like `example.internal`. In order to fully use this, you can modify local /etc/hosts entry to match private DNS zone, setup local DNS server, use SSH jump host or VPN that has access to a private DNS service, or access the services by IP address.
* point your public domain to Azure Name Servers (after deployment), so that your zone will be used for DNS lookups within your domain.  For this scenario, `example.com` will be used.

# Steps

## Create tf vars defaults

```bash
cat <<-EOF >> $TF_VARS
# AKS resource group
cluster_group         = "aks-basic"
cluster_location      = "westus2"
create_cluster_group  = true

# DNS resource group
dns_zone_group        = "dns-zones"
dns_zone_location     = "westus2"
create_dns_zone_group = true

# DNS Zone
domain = "<your-domain-goes-here>" # must be changed

# AKS
cluster_name        = "basic"
dns_prefix          = "basic"
EOF
```

### Azure DNS and AKS Resources

For simplicity, both Azure DNS and AKS resources can be a part in the same resource group.  However, enterprise settings where separation of concerns is important, these will likely be managed in two separate resource groups.

## Provision AKS Cluster

The `--target` (or `-target`) is required because modules do not support dependency mechanism. The resource group will need to be created first, before creating AKS.

```bash
# create resource group if it does not already exists
AZ_AKS_RESOURCE_GROUP=$(awk -F'"' '/cluster_group/{ print $2 }' terraform.tfvars)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_AKS_RESOURCE_GROUP}; then
  terraform apply --target "module.cluster_rg" --var create_cluster_group="true"
fi

AZ_DNS_RESOURCE_GROUP=$(awk -F'"' '/dns_zone_group/{ print $2 }' terraform.tfvars)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_DNS_RESOURCE_GROUP}; then
  terraform apply --target "module.dns_zone_rg" --var create_dns_zone_group="true"
fi


# create the AKS cluster
terraform apply --target "module.dns"
```

## Credentials for Kubectl

```bash
export AZ_AKS_CLUSTER_NAME="$(terraform output -raw kubernetes_cluster_name)"
export AZ_AKS_RESOURCE_GROUP="$(terraform output -raw cluster_resource_group_name)"
export KUBECONFIG=~/.kube/${AZ_AKS_CLUSTER_NAME}.yaml

az aks get-credentials \
  --resource-group $AZ_AKS_RESOURCE_GROUP \
  --name $AZ_AKS_CLUSTER_NAME \
  --file $KUBECONFIG
```

## Verify

```bash
kubectl get all --all-namespaces
```

# Cleanup

```bash
terraform destroy
```

# Links

* [Terraform Provider for Azure (Resource Manager): Examples](https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples)
* [Create a Kubernetes cluster with Azure Kubernetes Service using Terraform](https://docs.microsoft.com/en-us/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks)
* [Kubernetes Provider for Terraform: AKS (Azure Kubernetes Service)](https://github.com/hashicorp/terraform-provider-kubernetes/tree/main/_examples/aks)
