
## Bookinfo Deploy

```bash
kubectl config set-context --current --namespace bookinfo

RATINGS_POD=$(kubectl get pod -n bookinfo -l app=ratings -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$RATINGS_POD" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
```

## Gateway

```
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.10/samples/bookinfo/networking/bookinfo-gateway.yaml
```

## Ingres IP/Ports

```bash
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
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
