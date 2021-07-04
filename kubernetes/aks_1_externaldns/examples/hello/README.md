# hello-kubernetes

## Requirements

* General
  * Tools: `kubectl`
  * Kubernetes (AKS)
* DNS configuraiton autoamtion
  * Tools: `envsubst` or `helmfile`
  * ExternalDNS (`external-dns`) configured
  * environment variable: `AZ_DNS_DOMAIN`

## Deploy

## Using kubectl + envsubst

```bash
export AZ_DNS_DOMAIN='example.com'
kubectl create namespace hello
envsubst < hello_k8s.yaml.shtmpl | kubectl apply --namespace hello -f -
```

## Using helmfile

This requires `helm` and `helm-diff` installed in additon to `helmfile`

```bash
export AZ_DNS_DOMAIN='example.com'
helmfile apply
```
