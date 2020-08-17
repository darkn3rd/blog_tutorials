# Application

This deploys a demonistration application "hello-kubernetes" with external load balancer endpoint.

## Deploy

```bash
cat *.yaml | kubectl create --filename -
```

## Delete

```bash
cat *.yaml | kubectl delete --filename -
```
