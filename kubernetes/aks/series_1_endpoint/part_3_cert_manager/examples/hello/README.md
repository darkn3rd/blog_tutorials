# hello-kubernetes

## Requirements

* General
  * Tools: `kubectl`
  * Kubernetes (AKS)
* Ingress Requirements
  * ingress contoller installed (`ingress-nginx`)
* DNS configuraiton autoamtion
  * Tools: `envsubst` or `helmfile`
  * ExternalDNS (`external-dns`) configured
  * environment variable: `AZ_DNS_DOMAIN`
* TLS certificate autoamtion
  * Tools: `helm` and `helmfile`
  * Addons: `cert-manager` and `ingress-nginx` configured
  * environment variable: `AZ_DNS_DOMAIN` and `ACME_ISSUER`
    * referenced issuer is configured and installed

## Deploy

### Using kubectl + envsubst

This requires `kubectl` and `envsubst` are installed.

```bash
export AZ_DNS_DOMAIN='<your-domain-goes-here>'
export ACME_ISSUER='<issuer-name-goes-here>' # letsencrypt-prod or letsencrypt-straging
kubectl create namespace hello
envsubst < hello_k8s.yaml.shtmpl | kubectl apply --namespace hello -f -
```

### Using helmfile

This requires `helm` and `helm-diff` installed in additon to `helmfile`

```bash
export AZ_DNS_DOMAIN='<your-domain-goes-here>'
export ACME_ISSUER='<issuer-name-goes-here>' # letsencrypt-prod or letsencrypt-straging
helmfile apply
```
