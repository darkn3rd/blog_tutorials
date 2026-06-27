# AWS Load Balancer Controller

The **AWS Load Balancer Controller** manages AWS Elastic Load Balancing (ELBv2) resources natively inside an Amazon EKS cluster. It satisfies Kubernetes resource requirements by provisioning high-performance network load balancers across two distinct OSI layers:

### 🌐 Layer 4 Routing (Network Load Balancer - NLB)
* **Legacy/Standard:** `Service` resources configured as `type: LoadBalancer`.
* **Gateway API:** `Gateway` resources coupled with `TCPRoute` configurations.

### 🚀 Layer 7 Routing (Application Load Balancer - ALB)
* **Legacy/Standard:** Traditional `Ingress` resources.
* **Gateway API:** `Gateway` resources coupled with `HTTPRoute` or `GRPCRoute` configurations.

## Prerequisites 

Before deploying the controller, ensure your environment meets the following baseline requirements:

* **Core Cluster Components:** A functional Amazon EKS cluster running the standard **VPC CNI**, **kube-proxy**, and **CoreDNS** add-ons.
* **AWS IAM Access (Least Privilege):** You must configure fine-grained AWS API permissions for the controller using one of two supported authentication methods:
  * **EKS Pod Identity (Recommended):** Requires the `eks-pod-identity-agent` add-on to be installed on your cluster nodes.
  * **IRSA (IAM Roles for Service Accounts):** Requires an active OIDC Provider configured for your EKS cluster.

### EKS Cluster

These can be easily provisioned using one of the guides:

* [EKS via eksctl | VPC via eksctl](../../minimal/01_eksctl/README.md)
* [EKS via eksctl | VPC via AWS CLI](../../minimal/02_awscli_eksctl/README.md)
* [EKS via eksctl | VPC via Terraform](../../minimal/03_terraform_eksctl/README.md)
* [EKS via Terraform | VPC via Terraform (Native Resources)](../../minimal/04_terraform_native/README.md)
* [EKS via Terraform | VPC via Terraform (Community Modules)](../../minimal/05_terraform_modules/README.md)





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