# YAGES (Yet Another gRPC Echo Server) example

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
* Testing example
  * Tools: `grpcurl`

## Deploy

### Using Helmfile

```bash
export AZ_DNS_DOMAIN='<your-domain-goes-here>'
export ACME_ISSUER='<issuer-name-goes-here>' # letsencrypt-prod or letsencrypt-straging
helmfile apply
```

## Test Solution

```bash
grpcurl yages.$AZ_DNS_DOMAIN:443 yages.Echo.Ping | jq
grpcurl -d '{ "text" : "some fun here" }' yages.$AZ_DNS_DOMAIN:443 yages.Echo.Reverse
grpcurl yages.$AZ_DNS_DOMAIN:443 list
```
