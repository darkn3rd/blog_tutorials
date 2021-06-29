# cert-manager on AKS

## Published Articles

* https://joachim8675309.medium.com/aks-with-cert-manager-f24786e87b20

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


## Azure resources (AKS + Azure DNS zone)

```bash
source env.sh

az network dns zone create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME}

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

## Deploy Addons

```bash
. env.sh
helmfile apply

export ACME_ISSUER_EMAIL="<your-email-goes-here>"
helmfile --file issuers.yaml apply
```

## Deploy Example Applications

### Hello Kubernetes

See [README.MD](examples/hello/README.md) for further information.

### Dgraph

See [README.MD](examples/dgraph/README.md) for further information.

## Cleanup

### Delete Dgraph Example

Removing PVC will remove any external Azure Disks.  This is important as these will incur costs and are left around even after the AKS cluster is destroyed.

```bash
. env.sh
helm delete demo --namespace dgraph
kubectl delete pvc --namespace dgraph --selector release=demo
```

### Destroy AKS

```bash
. env.sh
az aks delete \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_CLUSTER_NAME
```

### Destroy Azure DNS

```bash
. env.sh
az network dns zone delete \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_DNS_DOMAIN
```

## Reseach

* Azure Guides
  * private certs: https://docs.microsoft.com/en-us/azure/aks/ingress-tls
  * public-cert + podIdentity + AzureDNS: https://cert-manager.io/docs/configuration/acme/dns01/azuredns/
* Helm Chart
  * chart ReadMe: https://artifacthub.io/packages/helm/cert-manager/cert-manager
  * values.yaml: https://github.com/jetstack/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml
* PodIdentity
  * https://azure.github.io/aad-pod-identity/
* ACME
  * https://cert-manager.io/docs/configuration/acme/
  * https://azure.github.io/application-gateway-kubernetes-ingress/how-tos/lets-encrypt/
