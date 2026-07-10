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

### Installing AWS Load Balancer Controller

You can setup and install AWS Load Balancer Controller with the following paths:

* [CLI](./01_cli/README.md) - setup using `helm`, `kubectl`, `aws`, and optional `eksctl` commands with using either IRSA or Pod-Identity association for authorization configuration.
* [Terraform](./02_terraform/README.md) - setup using `terraform` with either IRSA or Pod-Identity association for authorization configuration.
* [Python](./03_python/README.md) - setup using `boto3` and the `kubernetes` client directly (no `aws`/`kubectl`/`eksctl` calls, `helm` only) with either IRSA or Pod-Identity association for authorization configuration.

### ELBv2 Demos

After the AWS Load Balancer is installed, you test it by deploying service, ingress, or gateway manifests that triggering provisionign of either ALB or NLB.

* [Overview](./demos/README.md)
  * [Terraform](./demos/tf/README.md) - bring up the demos or use one at a time with `terraform -target`
  * [CLI](./demos/cli/README.md) - use script to bring up all the demos, or run through them manually.
  * [Python](./demos/python/README.md) - use script to bring up all the demos, via the `kubernetes` Python client.

### Verifying the Install

[`extras/audit`](./extras/audit/README.md) has four InSpec/`cinc-auditor` profiles, one per pipeline stage, to verify the cluster is ready before you install, that installation prep succeeded, that the controller is healthy, and that the demos above actually work end-to-end.

## Terminology

* **Provision** infrastructure (AWS resources)
* **Install** cluster capabilities (controllers, drivers, add-ons)
* **Deploy** workloads (applications and Kubernetes objects)
* **Audit** the environment (InSpec)

## Documentation References

* [Install AWS Load Balancer Controller with Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
* [Getting started with Gateway API](https://gateway-api.sigs.k8s.io/guides/getting-started/introduction/)
* [AWS Load Balancer Controller: Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
* [AWS Load Balancer Controller: Gateway API](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/gateway/gateway/)
