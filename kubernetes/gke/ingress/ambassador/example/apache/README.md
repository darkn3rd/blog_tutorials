# Apache HTTPd Examples


This is a basic test of ingress features using Apache HTTPd.

## Install

### Install using Emissary-Ingress CRDs

```bash
./test_emissary_ingress.sh
```

### Install using classic Kubernetes ingress API

```bash
./test_classic_ingress.sh
```

## Cleanup

### Delete resources for Apache HTTPd with Emissary-Ingress CRDs

```bash
# delete resources for classic ingress 
kubectl delete namespace "emissary-ingress-test"
```


### Delete resources for Apache HTTPd with classic Kubernetes ingress API

```bash
# delete resources for classic ingress 
kubectl delete namespace "ingress-test"
```