# Part 2: Deploying Ingress with Managed SSL using Reserved IP Address

## Step 1: Create IP Address

```bash
MY_ADDRESS_NAME=<address-name>  # e.g. acme-address-name

# reserve static IP address
gcloud compute addresses create $MY_ADDRESS_NAME --global 

# verify IP address is ready
gcloud compute addresses describe $MY_ADDRESS_NAME --global | \
  awk '/^address:/{print $2}'
```

## Step 2: Deploy Resources

```bash
MY_ADDRESS_NAME=<address-name>  # e.g. acme-address-name
MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-mng-ssl.test.acme.com

## Prepare Manifests
sed -e "s/\$MY_DNS_NAME/$MY_DNS_NAME/" \
    -e "s/\$MY_ADDRESS_NAME/$MY_ADDRESS_NAME/" \
    template_ingress.yaml > hello_ingress.yaml
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" \
    template_managed_cert.yaml > hello_managed_cert.yaml

## Deploy Resources
kubectl create --filename hello_deploy.yaml
kubectl create --filename hello_managed_cert.yaml
kubectl create --filename hello_service.yaml
kubectl create --filename template_ingress.yaml
```

## Testing

```bash
curl https://$MY_DNS_NAME
```

## Troubleshooting

### Kubectl

```bash
kubectl describe \
  managedcertificates.networking.gke.io/hello-k8s-gce-ssl2
```

### Gcloud 

```bash
DOMAINS_COL="managed.domains[].list(separator="$'\n'")"
FORMAT="table[box](name,type,managed.status,$DOMAINS_COL)"

gcloud compute ssl-certificates list \
 --filter "hello" \
 --format "$FORMAT"
```

## Cleanup

### Remove Deploy Resources

```bash
cat hello_*.yaml | kubectl delete --filename -
```

### Remove Reserved IP Address

```bash
gcloud compute addresses delete $MY_ADDRESS_NAME --global
```