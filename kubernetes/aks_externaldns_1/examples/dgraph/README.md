# Dgraph

## Requirements

* General
  * Tools: `helm` or `helmfile`
  * Kubernetes (AKS)
* Securing Dgraph (*allow list*)
  * evironment variables: `AZ_CLUSTER_NAME`, `AZ_RESOURCE_GROUP`
* DNS configuraiton autoamtion
  * Tools: `helm` or `helmfile`
  * ExternalDNS (`external-dns`) configured
  * environment variable: `AZ_DNS_DOMAIN`

## Security (Dgraph Service)

You can limit access with an *allow list*


```bash
source ../../env.sh # fetch AZ_RESOURCE_GROUP and AZ_CLUSTER_NAME

## Build Accept List
DG_ALLOW_LIST=$(az aks show \
  --name $AZ_CLUSTER_NAME \
  --resource-group $AZ_RESOURCE_GROUP | \
  jq -r '.networkProfile.podCidr,.networkProfile.serviceCidr' | \
  tr '\n' ','
)
# append home office IP address
MY_IP_ADDRESS=$(curl --silent ifconfig.me)
DG_ALLOW_LIST="${DG_ALLOW_LIST}${MY_IP_ADDRESS}/32"export DG_ALLOW_LIST
export DG_ALLOW_LIST
```

### Dgraph with Helmfile

```bash
export AZ_DNS_DOMAIN='example.com'
helmfile apply
```

### Dgraph using just Helm

```bash
export AZ_DNS_DOMAIN='example.com'
envsubst < chart-values.yaml.shtmpl > chart-values.yaml
kubectl create namespace dgraph
helm repo add dgraph https://charts.dgraph.io
helm install demo dgraph/dgraph \
  --namespace dgraph \
  --values chart-values.yaml \
  --version 0.0.17
```

### Verify Dgraph

```bash
curl --silent http://alpha.${AZ_DNS_DOMAIN}:8080/health | jq
```

### Populate Data

```bash
bash getting_started_data.sh
```

## Cleanup

### Delete Dgraph Example

Removing PVC will remove any external Azure Disks.  This is important as these will incur costs and are left around even after the AKS cluster is destroyed.

```bash
helm delete demo --namespace dgraph
kubectl delete pvc --namespace dgraph --selector release=demo
```
