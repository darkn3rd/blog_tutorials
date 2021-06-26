# Deploy ExternalDNS (AzureDNS) with AKS

* Blog Article:
    * https://joachim8675309.medium.com/extending-aks-with-external-dns-3da2703b9d52

# Create Global env.sh

Create a global env.sh to hold  all the values  we'll will use.

```bash
export AZ_RESOURCE_GROUP="external-dns"
export AZ_LOCATION="westus2"

export AZ_CLUSTER_NAME="demo-external-dns"
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

# Deploy Cloud Resources

## AKS

### Using existing automation from other projects)

You need to have an AKS cluster for this exercise.  For information about provisioning an AKS cluster, see [AKS Provision README](../../azure/aks/aks_provision_az/README.md)).  You can use that guide with this by running the following:

```bash
. env.sh

pushd ../../azure/aks/aks_provision_az/; ./create_cluster.sh; popd
```

### Using embedded scripts

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

### Using  BYOA (Bring Your Own AKS)

If you used another source to provision an AKS Kubernetes cluster, make sure that *Managed Identity* (aka *MSI*) is enabled.  You can example with:

```bash
az aks update -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME --enable-managed-identity
```

## Azure DNS Zone

You should have a domain registered, and then either configure Azure DNS to support a subdomain or transfer DNS to Azure DNS zone from the domain provider such as GoDaddy.  For examples on this, see [Azure DNS README](../../azure/azure_dns/README.md).

### Using Adjacent Project Scripts (includes GoDaddy)

There are  previous blog posts that demonstrated how to do this process with GoDaddy.  YOu can use those scripts with the following:

```bash
. env.sh

pushd ../../azure/azure_dns/
terraform init
# Create domain in Azure DNS
terraform apply --target module.azure_dns_domain
# point GoDaddy name servers to Azure DNS
# NOTE: Skip this if  you use a different service.  Refer to their  documentation
# for a similar procedure
terraform apply --target module.godaddy_dns_nameservers
popd
```

### Using Terraform

Included is a small Terraform script to initialize an Azure DNS Zone.  

```bash
. env.sh

pushd ./terraform
# initialize terraform providers
terraform init
# run the terraform script
terraform apply
popd
```

### Using Azure CLI

```bash
az network dns zone create -g $AZ_RESOURCE_GROUP -n $AZ_DNS_DOMAIN
```

### Verify Azure DNS Zone

```bash
# jq way
az network dns zone list | \
  jq ".[] | select(.name == \"$AZ_DNS_DOMAIN\")"

# JMES way
az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN']"
```

## Add Access to Azure DNS Zone

```bash
## get principal id from VMSS using JMESPath
export AZ_PRINCIPAL_ID=$(
  az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" | tr -d '"'
)

## using jq
export AZ_DNS_SCOPE=$(
  az network dns zone list |
   jq -r ".[] | select(.name == \"$AZ_DNS_DOMAIN\").id"
)

## using JMESPath
export AZ_DNS_SCOPE=$(
  az network dns zone list \
    --query "[?name=='$AZ_DNS_DOMAIN'].id" \
    --output table | tail -1
)

az role assignment create \
  --assignee "$AZ_PRINCIPAL_ID" \
  --role "DNS Zone Contributor" \
  --scope  "$AZ_DNS_SCOPE"
```

# Deploy ExternalDNS

## Deploy ExternalDNS using Helmfile

```bash
. env.sh
export AZ_TENANT_ID=$(az account show --query "tenantId" | tr -d '"')
export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')

helmfile apply
```

## Deploy ExternalDNS using Helm

```bash
. env.sh
export AZ_TENANT_ID=$(az account show --query "tenantId" | tr -d '"')
export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')

envsubst < chart-values.yaml.shtmpl > chart-values.yaml
kubectl create namespace kube-addons
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install external-dns bitnami/external-dns \
  --namespace kube-addons \
  --values chart-values.yaml \
  --version 5.1.1
```

##  Verify ExternalDNS

```bash
# Fetch Pord Name and Verify Logs
EXTERNAL_DNS_POD_NAME=$(
  kubectl \
    --namespace kube-addons get pods \
    --selector "app.kubernetes.io/name=external-dns,app.kubernetes.io/instance=external-dns" \
    --output name
)
kubectl logs --namespace kube-addons $EXTERNAL_DNS_POD_NAME
```

# Deploy Example Applications

## Hello Kubernetes

See [README.MD](examples/hello/README.md) for further information.


## Dgraph

See [README.MD](examples/dgraph/README.md) for further information.

# Cleanup

## Delete Dgraph Example

Removing PVC will remove any external Azure Disks.  This is important as these will incur costs and are left around even after the AKS cluster is destroyed.

```bash
. env.sh
helm delete demo --namespace dgraph
kubectl delete pvc --namespace dgraph --selector release=demo
```

## Destroy AKS

```bash
. env.sh
az aks delete \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_CLUSTER_NAME
```

## Destroy Azure DNS

```bash
. env.sh
az network dns zone delete \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_DNS_DOMAIN
```
