# AKS with Kube Identity

These guides will use kube-identity to allow access to cloud resources, specifically `Azure DNS`.

# Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [terraform](https://www.terraform.io/) - provisioning tool to create cloud resources

## Azure Subscription

An account needs to be registered to create an Azure subscripiton, and then after installing `az`, run:

```bash
az login
```

## Domain Resolution

* public domain, e.g. `example.com`, will have Azure DNS perform addresses resolution, assuming configured Azure DNS name server(s) as the authority for your domain; Follow instructions from you domain registrar, e.g. GoDaddy, OpenSRS, etc.
* private domain, e.g. `example.internal`, will required you to resolve addresses locally, such as editing `/etc/hosts` entries or setting up a local private DNS server like `dnsmasq`, or accessing the Azure DNS server from the the Azure VNET, such using SSH jump host or VPN.
## Using TLS Certificates

* public domain, e.g. `example.com`, is required for use with a trusted DNS certficate authority
* private domain, e.g. `example.internal`, can be used with untrusted self-signed certificates.  This requires adding an exception every time the website is visited.
* email-address is required to issue certificates from Let's Encrypte ACME CA
# Steps

## Create tf vars defaults

```bash
cat <<-EOF >> $TF_VARS
#############
# Azure Kubernetes Service
####################
cluster_group        = "aks-basic"
cluster_location     = "westus2"
# create or reference resource group for AKS cluster
create_cluster_group = true

cluster_name         = "basic"
dns_prefix           = "basic"

#############
# Azure DNS
####################
# create or reference resource group for Azure DNS
dns_zone_group        = "dns-zones"
dns_zone_location     = "westus2"
# create or reference exisitng Azure DNS zone
create_dns_zone_group = false

domain                = "<CHANGE_ME>" 
create_dns_zone       = false

#############
# Kubernetes Add-ons
####################
enable_attach_dns    = true # grants access to Azure DNS
enable_external_dns  = true
enable_ingress_nginx = true
enable_cert_manager  = true
# required to issue public CA certificates from Let's Encrypt
acme_issuer_email    = "<CHANGE_ME>" 
EOF
```

## Azure DNS and AKS cloud resources

For simplicity, both Azure DNS and AKS resources can be a part in the same resource group.  However, enterprise settings where separation of concerns is important, these will likely be managed in two separate resource groups.

The `--target` (or `-target`) is required because modules do not support dependency mechanism. The resource group will need to be created first, before the corresponding cloud resources.

### Provision Azure DNS Zone

```bash 
AZ_DNS_RESOURCE_GROUP=$(awk -F'"' '/dns_zone_group/{ print $2 }' terraform.tfvars)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_DNS_RESOURCE_GROUP}; then
  terraform apply --target "module.dns_zone_rg" --var create_dns_zone_group="true"
fi

# create or reference Azure DNS zone depending on 'create_dns_zone' setting
terraform apply --target "module.dns"
```

### Provision AKS Cluster

```bash
# create resource group if it does not already exists
AZ_AKS_RESOURCE_GROUP=$(awk -F'"' '/cluster_group/{ print $2 }' terraform.tfvars)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_AKS_RESOURCE_GROUP}; then
  terraform apply --target "module.cluster_rg" --var create_cluster_group="true"
fi

# create kubernetes cluster
terraform apply --target "module.aks"
```
### Credentials for Kubectl

```bash
export AZ_AKS_CLUSTER_NAME="$(terraform output -raw kubernetes_cluster_name)"
export AZ_AKS_RESOURCE_GROUP="$(terraform output -raw cluster_resource_group_name)"
export KUBECONFIG=~/.kube/${AZ_AKS_CLUSTER_NAME}.yaml

az aks get-credentials \
  --resource-group $AZ_AKS_RESOURCE_GROUP \
  --name $AZ_AKS_CLUSTER_NAME \
  --file $KUBECONFIG
```

### Verify

```bash
kubectl get all --all-namespaces
```

## Kubernetes Addons


```bash
# grant access to Azure DNS via kubelet id - required for cert-manager and external-dns
terraform apply --target "azurerm_role_assignment.attach_dns" --var enable_attach_dns="true"
# external-dns
terraform apply --target "helm_release.external_dns" --var enable_external_dns="true"
# ingress-nginx
terraform apply --target "helm_release.ingress_nginx" --var enable_ingress_nginx="true"
# cert-manager
terraform apply --target "helm_release.cert_manager" --var enable_cert_manager="true"
terraform apply --target "helm_release.cert_manager_issuers" --var enable_cert_manager="true" --var acme_issuer_email="<your-email-goes-here>"
```

# Cleanup

```bash
terraform destroy
```

# Links

* [Terraform Provider for Azure (Resource Manager): Examples](https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples)
* [Create a Kubernetes cluster with Azure Kubernetes Service using Terraform](https://docs.microsoft.com/en-us/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks)
* [Kubernetes Provider for Terraform: AKS (Azure Kubernetes Service)](https://github.com/hashicorp/terraform-provider-kubernetes/tree/main/_examples/aks)
