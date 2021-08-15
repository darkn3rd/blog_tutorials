# Deploy ingress-nginx on AKS

## Published Articles

* https://joachim8675309.medium.com/aks-with-ingress-nginx-7c51da500f69

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [helm](https://helm.sh/docs/intro/install/), [helm-diff](https://github.com/databus23/helm-diff), [helmfile](https://github.com/roboll/helmfile)

## Setup Environment Vars

Create an `env.sh` and filling out the appropriate values.

```bash
export AZ_RESOURCE_GROUP="ingress-demo"
export AZ_LOCATION="westus2"
export AZ_CLUSTER_NAME="ingress-demo"
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME
export AZ_DNS_DOMAIN="<replace-with-your-domain>" # example.com
export AZ_TENANT_ID=$(az account show --query "tenantId" | tr -d '"')
export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')
```

## Install AKS + Azure DNS

```bash
. env.sh
bash ./scripts/create_azure_resources.sh
```

## Configuure Acccess to Azure DNS

```bash
. env.sh
bash ./scripts/config_azure_dns_access.sh
```

### Authorize access to Azure DNS

```bash
source env.sh

## get principal id from VMSS using JMESPath
export AZ_PRINCIPAL_ID=$(
  az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" | tr -d '"'
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

## Deploy Addons

```bash
. env.sh
helmfile apply
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
