# AWS LBC Demos with kubectl (Python-scripted)

These demos deploy four scenarios by calling `kubectl` via `subprocess` - a
Python-scripted version of running those commands by hand. Each demo lands in its own
namespace and allows the **AWS Load Balancer Controller** (**AWS LBC**) to provision a
different kind of AWS load balancer:

| Demo | Namespace (default) | Produces |
| --- | --- | --- |
| Service/NLB | `demo-nlb` | Network Load Balancer, via a `Service` of type `LoadBalancer` |
| Ingress/ALB | `demo-alb` | Application Load Balancer, via an `Ingress` |
| Gateway+TCPRoute/NLB | `demo-gwtcp` | Network Load Balancer, via Gateway API |
| Gateway+HTTPRoute/ALB | `demo-gwhttp` | Application Load Balancer, via Gateway API |

Works against a cluster with the AWS Load Balancer Controller installed, however that
install happened - these demos only create Kubernetes objects and don't care how the
controller got there.

## No third-party Python dependencies

Every call here shells out to `kubectl` - there's nothing to `pip install`. Just standard
library (`subprocess`, `argparse`) plus `kubectl` on your `PATH`.

## Prerequisites

* Amazon EKS Cluster
* AWS Load Balancer Controller installed (Gateway API demos also need the Gateway API CRDs installed)
* Credentials to access the EKS cluster, usually set up via `KUBECONFIG`

No AWS credentials are needed here: these demos only create Kubernetes objects and let
the already-installed controller reconcile them into AWS load balancers.

## Deploy all 4 demos at once

```bash
./deploy_demos.py
```

This creates each namespace, deploys the demo app, and applies the Kubernetes resources
that cause AWS LBC to provision the load balancer.

```bash
SVC_NLB_NAMESPACE=demo-nlb \
ING_ALB_NAMESPACE=demo-alb \
GW_NLB_NAMESPACE=demo-gwtcp \
GW_ALB_NAMESPACE=demo-gwhttp \
  ./deploy_demos.py
```

Run `./deploy_demos.py --help` for details.

### Verify

```bash
../../test_demos.sh
```

Waits for each demo's load balancer address to appear, waits for DNS to resolve, then
curls it. Reports PASS/FAIL per demo with bounded timeouts (won't hang forever if AWS
never finishes provisioning).

### Clean up

```bash
./clean_demos.py
```

Deletes the Kubernetes load balancer resources, waits for AWS LBC to deprovision the AWS
load balancers, then deletes each namespace. Accepts the same namespace override env
vars as `deploy_demos.py`. Run `./clean_demos.py --help` for details.
