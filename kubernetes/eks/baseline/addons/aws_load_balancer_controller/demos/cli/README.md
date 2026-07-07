# AWS LBC Demos with kubectl

These demos deploy **Kubernetes** resources with plain `kubectl` and manifests instead of **Terraform**. Each demo lands in its own namespace and allows the **AWS Load Balancer Controller** (**AWS LBC**) to provision a different kind of AWS load balancer:

| Demo | Namespace (default) | Produces |
| --- | --- | --- |
| Service/NLB | `demo-nlb` | Network Load Balancer, via a `Service` of type `LoadBalancer` |
| Ingress/ALB | `demo-alb` | Application Load Balancer, via an `Ingress` |
| Gateway+TCPRoute/NLB | `demo-gwtcp` | Network Load Balancer, via Gateway API |
| Gateway+HTTPRoute/ALB | `demo-gwhttp` | Application Load Balancer, via Gateway API |

## Prerequisites

* Amazon EKS Cluster
* AWS Load Balancer Controller installed (Gateway API demos also need the Gateway API CRDs installed)
* Credentials to access the EKS cluster, usually set up via `KUBECONFIG`
* Credentials to access AWS, usually set up via `AWS_PROFILE`

## Option 1: Deploy all 4 demos at once

```bash
./create_demos.sh
```

This creates each namespace, deploys the demo app, and applies the **Kubernetes** resources that cause **AWS LBC** to provision the load balancer.

```bash
SVC_NLB_NAMESPACE=demo-nlb \
ING_ALB_NAMESPACE=demo-alb \
GW_NLB_NAMESPACE=demo-gwtcp \
GW_ALB_NAMESPACE=demo-gwhttp \
  ./create_demos.sh
```

Run `./create_demos.sh --help` for details.

### Verify

```bash
../test_demos.sh
```

Waits for each demo's load balancer address to appear, waits for DNS to resolve, then
curls it. Reports PASS/FAIL per demo with bounded timeouts (won't hang forever if AWS
never finishes provisioning).

### Clean up

```bash
./clean_demos.sh
```

Deletes the **Kubernetes** load balancer resources, waits for **AWS LBC** to deprovision the AWS load balancers, then deletes each namespace.  Accepts the same namespace override env vars as `create_demos.sh`. Run `./clean_demos.sh --help` for details.

## Option 2: Walk through a single demo by hand

If you'd rather go step-by-step (deploy, inspect, curl, clean up manually) instead of
running the scripts, each demo has its own directory with a README walkthrough:

* [`01.svc_nlb/`](01.svc_nlb/README.md) - Service with NLB
* [`02.ing_alb/`](02.ing_alb/README.md) - Ingress with ALB
* [`03.gw_nlb/`](03.gw_nlb/README.md) - Gateway with NLB (TCPRoute)
* [`04.gw_alb/`](04.gw_alb/README.md) - Gateway with ALB (HTTPRoute)

Each of those READMEs covers setup, deploying, verifying, testing with `curl`, and
cleanup for that one demo in isolation.
