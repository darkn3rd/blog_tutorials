# Application

This deploys a demonistration application "hello-kubernetes" with external load balancer endpoint.

## Create Ingress from Template

```bash
sed -e "s/\$MY_DNS_NAME/$MY_DNS_NAME/" \
  template-ingress.yaml > hello-k8s-ing
```
## Deploy

```bash
cat hello-k8s-*.yaml | kubectl create --filename -
```

## Delete

```bash
cat hello-k8s-*.yaml | kubectl delete --filename -
```
