

## AKS Cluster

You need to have an AKS cluster for this exercise.  For information about provisioning an AKS cluster, see [AKS Provision README](../../azure/aks/aks_provision_az/README.md)).  You can use that guide with this by running the following:

```bash
export AZ_RESOURCE_GROUP="blog-test"
export AZ_CLUSTER_NAME="blog-test"
export AZ_LOCATION="westus2"
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME

pushd ../../azure/aks/aks_provision_az/; ./create_cluster.sh; popd
```

If you used anoterh source to provision an AKS Kubernetes clusgter, make sure that MSI is enabled.  You can example with:

```bash
az aks update -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME --enable-managed-identity
```

## Domain Registration

You should have a domain registered, and then either configure Azure DNS to support a subdomain or transfer DNS to Azure DNS zone from the domain provider such as GoDaddy.  For examples on this, see [Azure DNS README](../../azure/azure_dns/README.md). As an example, if you were using GoDaddy wanted to transfer your domain to a Azure DNS, you can do the following:

```bash
export GODADDY_API_KEY="<secret_goes_here>"
export GODADDY_API_SECRET="<secret_goes_here>"
export TF_VAR_domain="<your-domain-name-goes-here>"
export TF_VAR_resource_group_name="blog-test"
export TF_VAR_location="westus"

pushd ../../azure/azure_dns/
terraform init
terraform apply --target module.azure_dns_domain
terraform apply --target module.godaddy_dns_nameservers
popd
```

### Add Access to Azure DNS Zone

```bash
export AZ_RESOURCE_GROUP="blog-test"
export AZ_CLUSTER_NAME="blog-test"
export AZ_PRINCIPAL_ID=$(az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME  --query "identityProfile.kubeletidentity.objectId" | tr -d '"')
export AZ_DNS_SCOPE=$(az network dns zone list | jq -r ".[] | select(.name == \"$AZ_DNS_DOMAIN\").id")
# apparently this grants ALL access to EVERYTHING in the RG NOT SAFE
# NOTE: FIX THIS
az role assignment create \
  --assignee "$AZ_PRINCIPAL_ID" \
  --role "DNS Zone Contributor" \
  --resource-group "$AZ_RESOURCE_GROUP"
```

### Deploy

```bash
export AZ_TENANT_ID=$(az account show --query "tenantId" | tr -d '"')
export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')
export AZ_RESOURCE_GROUP="blog-test"
export TF_VAR_domain="<your-domain-name-goes-here>"

# Deploy External DNS
helmfile apply

# Fetch Pord Name and Verify Logs
EXTERNAL_DNS_POD_NAME=$(
  kubectl \
    --namespace kube-addons get pods \
    --selector "app.kubernetes.io/name=external-dns,app.kubernetes.io/instance=external-dns" \
    --output name
)
kubectl logs --namespace kube-addons $EXTERNAL_DNS_POD_NAME
```

### Example

```bash
export TF_VAR_domain="<your-domain-name-goes-here>"
kubectl create namespace hello
envsubst < hello_k8s.yaml.shtmpl | kubectl apply --namespace hello -f -
```

## Cleanup

```bash
# cleanup example
envsubst < hello_k8s.yaml.shtmpl | kubectl --namespace hello delete -f -
kubectl delete namespace hello

# external dns
helmfile delete
kubectl delete namespace kube-addons

# delete kubernetes cluster
pushd ../../azure/aks/aks_provision_az/; ./delete_cluster.sh; popd
```

## References

* Azure DNS
  * [How to protect DNS zones and records](https://docs.microsoft.com/en-us/azure/dns/dns-protect-zones-recordsets)

https://docs.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest

* AKS
  * Private Cluster: https://docs.microsoft.com/en-us/azure/aks/private-clusters
* https://github.com/bitnami/charts
* https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/azure.md
* Managed Identity
  * https://docs.microsoft.com/en-us/azure/aks/use-managed-identity
  * https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview
  * https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-identity
  * https://www.stacksimplify.com/azure-aks/azure-kubernetes-service-externaldns/

  * AD Integration
    * https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli
  * Pod Identity
    * https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
