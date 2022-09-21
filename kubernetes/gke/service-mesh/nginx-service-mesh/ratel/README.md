# Ratel

## Deploy Ratel with Manual Injection

```bash
kubectl get namespace "ratel" > /dev/null 2> /dev/null \
 || kubectl create namespace "ratel" \
 && kubectl label namespaces "ratel" name="ratel"

helmfile --file helmfile.yaml template \
  | nginx-meshctl inject \
  | kubectl apply --namespace "ratel" --filename -
```

## Virtual Server

```bash
NSM_ACCESS_CONTROL_MODE=$(nginx-meshctl config | jq -r .accessControlMode)
helmfile --file vs.yaml apply

RESOURCES="all,certificate,virtualserver"
if [[ "$NSM_ACCESS_CONTROL_MODE" == "deny" ]]; then
  RESOURCES="$RESOURCES,HTTPRouteGroup,TrafficTarget"
fi

kubectl get $RESOURCES --namespace ratel
````
