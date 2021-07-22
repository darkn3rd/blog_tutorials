

## Environment

```bash
export AZ_RESOURCE_GROUP=linkerd-test
export AZ_CLUSTER_NAME=linkerd-test
export AZ_LOCATION=westus2
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME.yaml

export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')

# only used with helm chart
LINKERD_EXP=$(date -v+8760H +"%Y-%m-%dT%H:%M:%SZ" 2> /dev/null) || \
 LINKERD_EXP=$(date -d '+8760 hour' +"%Y-%m-%dT%H:%M:%SZ")
export LINKERD_EXP

```

## Install Linkerd

### Generate Certificates

```bash
step certificate create root.linkerd.cluster.local \
 certs/ca.crt certs/ca.key \
 --profile root-ca --no-password --insecure

step certificate create identity.linkerd.cluster.local \
 certs/issuer.crt certs/issuer.key \
 --profile intermediate-ca --not-after 8760h \
 --no-password --insecure \
 --ca certs/ca.crt --ca-key certs/ca.key
```

### Deploy Linkerd

```bash
linkerd install \
  --identity-trust-anchors-file certs/ca.crt \
  --identity-issuer-certificate-file certs/issuer.crt \
  --identity-issuer-key-file certs/issuer.key \
  | kubectl apply -f -
```


### Verify Linkerd

```bash
kubectl get all --namespace "linkerd"
linkerd check
```

## Liknerd Extensions

### Viz Dashboard

```bash
linkerd viz install | kubectl apply -f -
kubectl get all --namespace "linkerd-viz"
linkerd viz check
```

### Jaeger

```bash
linkerd jaeger install | kubectl apply -f -
kubectl get all --namespace "linkerd-jaeger"
linkerd jaeger check
```

## Dgraph Example

### Deploy Dgraph

```bash
kubectl create namespace "dgraph"
helm template "demo" dgraph/dgraph --version 0.0.17 | \
 linkerd inject --skip-inbound-ports 5080,7080 --skip-outbound-ports 5080,7080 - | \
 kubectl apply --namespace "dgraph" --filename -
kubectl get all --namespace "dgraph"
```

### Service Profile


```bash
curl -sOL https://raw.githubusercontent.com/dgraph-io/dgraph/master/protos/pb.proto
linkerd profile --proto pb.proto --namespace dgraph dgraph-svc | \
  kubectl apply --namespace "dgraph" --filename -
```


## Cleanup

```bash

helm template "demo" dgraph/dgraph | kubectl delete --namespace "dgraph" --filename -
kubectl delete pvc --namespace "dgraph" --selector release="demo"
