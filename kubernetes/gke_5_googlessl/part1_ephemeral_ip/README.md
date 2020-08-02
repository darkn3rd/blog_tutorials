# Part1: Deploying Ingress with Managed SSL

## Deploy Resources

```bash
MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-mng-ssl.test.acme.com

## Prepare Manifests
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" template_ingress.yaml > hello_ingress.yaml
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" template_managed_cert.yaml > hello_managed_cert.yaml

## Deploy Resources
kubectl create --filename hello_deploy.yaml
kubectl create --filename hello_managed_cert.yaml
kubectl create --filename hello_service.yaml
kubectl create --filename template_ingress.yaml
```

## Troubleshooting

### Kubectl

```bash
kubectl describe \
  managedcertificates.networking.gke.io/hello-k8s-gce-ssl
```

### Gcloud 

```bash
DOMAINS_COL="managed.domains[].list(separator="$'\n'")"
FORMAT="table[box](name,type,managed.status,$DOMAINS_COL)"

gcloud compute ssl-certificates list \
 --filter "hello" \
 --format "$FORMAT"
```

## Testing

```bash
curl https://$MY_DNS_NAME
```

## Cleanup

```bash
cat hello_*.yaml | kubectl delete --filename -
```