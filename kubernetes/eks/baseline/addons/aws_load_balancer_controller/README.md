


* [Install AWS Load Balancer Controller with Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
* [Getting started with Gateway API](https://gateway-api.sigs.k8s.io/guides/getting-started/introduction/)
* [AWS Load Balancer Controller: Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
* [AWS Load Balancer Controller: Gateway API](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/gateway/gateway/)


Standard Channel CRDs: `GatewayClass`, `Gateway`, `HTTPRoute`, and `ReferenceGrant`
Experimental Channel CRDs: `TCPRoute`, `TLSRoute`, and `UDPRoute`

```bash
kubectl get crd grpcroutes.gateway.networking.k8s.io -ojsonpath="{.status.storedVersions}"
kubectl get crd referencegrants.gateway.networking.k8s.io -ojsonpath="{.status.storedVersions}"

crds=("GRPCRoutes" "ReferenceGrants")

for crd in "${crds[@]}"; do
  output=$(kubectl get "${crd}" -A -o json)

  echo "$output" | jq -c '.items[]' | while IFS= read -r resource; do
    namespace=$(echo "$resource" | jq -r '.metadata.namespace')
    name=$(echo "$resource" | jq -r '.metadata.name')
    kubectl patch "${crd}" "${name}" -n "${namespace}" --type='json' -p='[{"op": "replace", "path": "/metadata/annotations/migration-time", "value": "'"$(date +%Y-%m-%dT%H:%M:%S)"'" }]'
  done
done

kubectl patch customresourcedefinitions referencegrants.gateway.networking.k8s.io --subresource='status' --type='merge' -p '{"status":{"storedVersions":["v1beta1"]}}'
kubectl patch customresourcedefinitions grpcroutes.gateway.networking.k8s.io --subresource='status' --type='merge' -p '{"status":{"storedVersions":["v1"]}}'

```