

## env.sh

```bash
export AZ_RESOURCE_GROUP="ingress-nginx"
export AZ_LOCATION="westus2"

export AZ_CLUSTER_NAME="ingress-test"
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME

export AZ_DNS_DOMAIN="example.com"

## GoDaddy API credentials (if GoDaddy is used)
export GODADDY_API_KEY="<secret_goes_here>"
export GODADDY_API_SECRET="<secret_goes_here>"

## Terraform variable definitions (if Terraform is used)
export TF_VAR_resource_group_name=$AZ_RESOURCE_GROUP
export TF_VAR_location=$AZ_LOCATION
export TF_VAR_domain=$AZ_DNS_DOMAIN
```

## AKS

```bash
. env.sh

az aks create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --generate-ssh-keys \
  --vm-set-type VirtualMachineScaleSets \
  --node-vm-size ${AZ_VM_SIZE:-Standard_DS2_v2} \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --node-count 3 \
  --zones 1 2 3

az aks get-credentials \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --file ${KUBECONFIG:-$HOME/.kube/config}
```

## Reseach

* Azure Guides
  * private certs: https://docs.microsoft.com/en-us/azure/aks/ingress-tls
  * public-cert + podIdentity + AzureDNS: https://cert-manager.io/docs/configuration/acme/dns01/azuredns/
* Helm Chart
  * https://artifacthub.io/packages/helm/cert-manager/cert-manager
* PodIdentity
  * https://azure.github.io/aad-pod-identity/
