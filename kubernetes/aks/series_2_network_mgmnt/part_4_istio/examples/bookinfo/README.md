# Bookinfo

This is the demonstration application from Istio.

## Bookinfo Deploy

```bash
kubectl config set-context --current --namespace bookinfo

RATINGS_POD=$(kubectl get pod \
  --namespace bookinfo \
  --selector app=ratings \
  --output jsonpath='{.items[0].metadata.name}'
)

kubectl exec "$RATINGS_POD" \
  --container ratings \
  -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
```

## Gateway

```bash
ISTIO_BOOKINFO_GATEWAY_MANIFEST=https://raw.githubusercontent.com/istio/istio/release-1.10/samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl apply --namespace bookinfo --filename $ISTIO_BOOKINFO_GATEWAY_MANIFEST
```

## Ingres IP/Ports

```bash
export INGRESS_HOST=$(kubectl get service istio-ingressgateway \
  --namespace istio-system \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)
export INGRESS_PORT=$(kubectl get service istio-ingressgateway \
  --namespace istio-system \
  --output jsonpath='{.spec.ports[?(@.name=="http2")].port}'
)
export SECURE_INGRESS_PORT=$(kubectl get service istio-ingressgateway \
  --namespace istio-system \
  --output jsonpath='{.spec.ports[?(@.name=="https")].port}'
)

export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo "http://$GATEWAY_URL/productpage"
```

In another tab, launch kiali, unless it is launched already.

```bash
istioctl dashboard kiali
```

Generate traffic:

```bash
for i in $(seq 1 100); do curl -s -o /dev/null "http://$GATEWAY_URL/productpage"; done
```
