# Dgraph

## Requirements

* General
  * Tools: `helm` and `helmfile`
  * Kubernetes (AKS) with managed identity
    * Access to Azure DNS zone by addons `external-dns` and `ingress-nginx`
* Securing Dgraph (*allow list*)
  * evironment variables: `AZ_CLUSTER_NAME`, `AZ_RESOURCE_GROUP`
* DNS configuraiton autoamtion
  * Tools: `helm` or `helmfile`
  * Addons: ExternalDNS (`external-dns`) configured
  * environment variable: `AZ_DNS_DOMAIN`
* TLS certificate automation
  * Tools: `helm` and `helmfile`
  * Addons: `cert-manager` and `ingress-nginx` configured
  * environment variable: `AZ_DNS_DOMAIN` and `ACME_ISSUER`
    * referenced issuer is configured and installed
* uploading schema and data
  * Tools: `python3` and `pip`
  * Modules: `pydgraph` and `certifi`

## Security (Dgraph Service)

You can limit access with an *allow list*:

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
DG_ALLOW_LIST="${DG_ALLOW_LIST}${MY_IP_ADDRESS}/32"
export DG_ALLOW_LIST
```

## Deploy

### Using Helmfile

```bash
export AZ_DNS_DOMAIN='<your-domain-goes-here>'
export ACME_ISSUER='<issuer-name-goes-here>' # letsencrypt-prod or letsencrypt-straging
helmfile apply
```

## Verify Dgraph (HTTPS)

```bash
[[ "$ACME_ISSUER" == "letsencrypt-staging" ]] && CURL_K_OPT="--insecure"
curl --silent $CURL_K_OPT https://alpha.${AZ_DNS_DOMAIN}/health | jq
```

## Verify GRPC Works

```bash
[[ "$ACME_ISSUER" == "letsencrypt-staging" ]] && CURL_K_OPT="--insecure"
curl -sOL https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto
grpcurl $CURL_K_OPT -proto api.proto dgraph.${AZ_DNS_DOMAIN}:443 api.Dgraph/CheckVersion
```

## Populate Data using GRPC

See [README.md](data/README.md) for further information.

## Cleanup

Removing PVC will remove any external Azure Disks.  This is important as these will incur costs and are left around even after the AKS cluster is destroyed.

```bash
helm delete demo --namespace dgraph
kubectl delete pvc --namespace dgraph --selector release=demo
```
