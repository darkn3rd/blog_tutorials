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

## Deploy

### Using kubectl + envsubst

```bash
export AZ_DNS_DOMAIN='<your-domain-goes-here>'
kubectl create namespace hello
envsubst < hello_k8s.yaml.shtmpl | kubectl apply --namespace hello -f -
```

### Using helmfile

This requires `helm` and `helm-diff` installed in additon to `helmfile`

```bash
export AZ_DNS_DOMAIN='<your-domain-goes-here>'
helmfile apply
```
