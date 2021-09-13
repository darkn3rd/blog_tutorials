# Deploy ExternalDNS (AzureDNS) with AKS

## Published Blogs

  * https://joachim8675309.medium.com/extending-aks-with-external-dns-3da2703b9d52

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [helm](https://helm.sh/docs/intro/install/), [helm-diff](https://github.com/databus23/helm-diff), [helmfile](https://github.com/roboll/helmfile)

# Create Global env.sh

Create a global env.sh to hold  all the values  we'll will use.

```bash
export AZ_RESOURCE_GROUP="external-dns"
export AZ_LOCATION="westus2"
export AZ_AKS_CLUSTER_NAME="demo-external-dns"
export KUBECONFIG=~/.kube/$AZ_AKS_CLUSTER_NAME.yaml

export AZ_DNS_DOMAIN="<replace-with-your-domain>" # example.com
```

# Deploy Cloud Resources

## AKS

### Using embedded scripts

```bash
. env.sh

az aks create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_AKS_CLUSTER_NAME} \
  --generate-ssh-keys \
  --vm-set-type VirtualMachineScaleSets \
  --node-vm-size ${AZ_VM_SIZE:-Standard_DS2_v2} \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --node-count 3 \
  --zones 1 2 3

az aks get-credentials \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_AKS_CLUSTER_NAME} \
  --file ${KUBECONFIG:-$HOME/.kube/config}
```

## Azure DNS Zone

For this tutorial, an Azure DNS zone is required to illustrate the automation between Kubernetes and Azure DNS through External DNS.

For best results, using a public registered domain is optimal.  For this path, `example.com`, will be used as an example domain.  You can also use a private domain that will not be resolvable on the public Internet, such as `example.iternal`.  Below are some notes on both of these paths:

* public register domain
  * sub-domain like `stage.example.com` - create NS record on the service provicer, e.g. GoDaddy, OpenSRS, etc. that points to Azure DNS name servers.
  * full domain like `example.com` - transfer control of the domain from the service provider to use Azure DNS nameservers.
* private domain
  * local resolution - create duplicate entries in local DNS server or `/etc/hosts`
  * remote resolution - operate from within the private network (VPN) or through a jump host or bation host.


### Creating Azure DNS Zone with Azure CLI


```bash
az network dns zone create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_DNS_DOMAIN}
```

### Creating Azure DNS Zone with Terraform

* see [terraform/README.md](./terraform/README.md)

### Related

I have previous articles that walk through how to do transfer of control to Azure DNS from GoDaddy.  The process should be similar for other domain name providers.

* [Azure DNS README](../../../../azure/azure_dns/README.md)

### Verify Azure DNS Zone

```bash
# JMES
az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN']" --output table
```

## Add Access to Azure DNS Zone using kublet identity

```bash
## get principal id from VMSS using JMESPath
export AZ_PRINCIPAL_ID=$(
  az aks show -g $AZ_RESOURCE_GROUP -n $AZ_AKS_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" --output tsv
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
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

helmfile apply
```

## Deploy ExternalDNS using Helm

```bash
. env.sh
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

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
  --name $AZ_AKS_CLUSTER_NAME
```

## Destroy Azure DNS

```bash
. env.sh
az network dns zone delete \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_DNS_DOMAIN
```
