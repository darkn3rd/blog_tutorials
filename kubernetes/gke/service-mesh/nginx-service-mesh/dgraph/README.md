# Deploying Dgraph

## Deploying with Auto Injection

If auto-injection is enabled, you can deploy with:

**NOTE**: Due to [Issue 74](https://github.com/nginxinc/nginx-service-mesh/issues/74), intra-node communication with ports `5080` and `7080` will fail.

```bash
helmfile apply
```

## Deploying with Manual Injection

If auto-injection is disabled, you have to do manual injection:

**NOTE**: Due to [Issue 74](https://github.com/nginxinc/nginx-service-mesh/issues/74), intra-node communication with ports `5080` and `7080` will fail.

```bash
kubectl get namespace "dgraph" > /dev/null 2> /dev/null \
 || kubectl create namespace "dgraph" \
 && kubectl label namespaces "dgraph" name="dgraph"

helmfile template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "dgraph" --filename -
```

## WORKAROUND: Manual injection excluding 5080 and 7080 ports

```bash
kubectl get namespace "dgraph" > /dev/null 2> /dev/null \
 || kubectl create namespace "dgraph" \
 && kubectl label namespaces "dgraph" name="dgraph"

helmfile template \
 | nginx-meshctl inject \
     --ignore-incoming-ports 5080,7080 \
     --ignore-outgoing-ports 5080,7080 \
 | kubectl apply --namespace "dgraph" --filename -
```
