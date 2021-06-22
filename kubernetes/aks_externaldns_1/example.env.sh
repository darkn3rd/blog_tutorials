# resource group
export AZ_RESOURCE_GROUP="external-dns"
export AZ_LOCATION="westus"
# domain name you will use, e.g. example.com
export AZ_DNS_DOMAIN="example.com"
# AKS cluster name and local kubeconfig configuration
export AZ_CLUSTER_NAME="external-dns-demo"
export KUBECONFIG=${HOME}/.kube/${AZ_CLUSTER_NAME}
# Fetch tenant and subscription ids for external-dns
export AZ_TENANT_ID=$(az account show --query tenantId | tr -d '"')
export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')
