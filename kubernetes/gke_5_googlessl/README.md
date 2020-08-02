# GKE 5: Deploying Ingress with Managed SSL



## Managed SSL with Ephemeral IP Address

It can take about 20 minutes or longer for the certificate to be fully provisioned with an active state.

```bash
## Create Manifest
$MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-mng-ssl.test.acme.com

## Prepare Manifests
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" template_ingress.yaml > hello_ingress.yaml
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" template_managed_cert.yaml > hello_managed_cert.yaml

## Deploy Resources
kubectl create --filename hello_deploy.yaml
kubectl create --filename hello_managed_cert.yaml
kubectl create --filename hello_service.yaml
kubectl create --filename template_ingress.yaml
```
