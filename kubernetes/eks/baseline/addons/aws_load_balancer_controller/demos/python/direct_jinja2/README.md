# AWS LBC Demos with the Kubernetes Python client (Jinja2 templates)

These demos deploy four scenarios using the `kubernetes` client library. Every manifest is
a separate Jinja2 template file under [`templates/`](templates), rendered to YAML text with
`ns`/`app_name` variables, parsed to a dict, and passed as the `body=` argument to the
matching typed client method (`create_namespaced_deployment`, `create_namespaced_service`,
...). Custom resources (`Gateway`, `TCPRoute`, `LoadBalancerConfiguration`, ...) have no
typed `create_namespaced_<kind>()` method to call, so those fall back to the
`DynamicClient`'s generic apply.

| Demo | Namespace (default) | Produces |
| --- | --- | --- |
| Service/NLB | `demo-nlb` | Network Load Balancer, via a `Service` of type `LoadBalancer` |
| Ingress/ALB | `demo-alb` | Application Load Balancer, via an `Ingress` |
| Gateway+TCPRoute/NLB | `demo-gwtcp` | Network Load Balancer, via Gateway API |
| Gateway+HTTPRoute/ALB | `demo-gwhttp` | Application Load Balancer, via Gateway API |

Works against a cluster with the AWS Load Balancer Controller installed, however that
install happened - these demos only create Kubernetes objects and don't care how the
controller got there.

## Templates

```
templates/
  namespace.yaml.j2
  deployment.yaml.j2
  service_clusterip.yaml.j2
  service_nlb.yaml.j2
  ingress_alb.yaml.j2
  gateway_nlb.yaml.j2    # GatewayClass + Gateway + TCPRoute + LoadBalancerConfiguration + TargetGroupConfiguration
  gateway_alb.yaml.j2    # GatewayClass + Gateway + HTTPRoute + LoadBalancerConfiguration + TargetGroupConfiguration
```

The two Gateway templates are multi-document YAML (`---`-separated), matching how the
resources are conceptually one bundle - `deploy_demos.py` parses each document out and
applies them individually.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Requires Python >= 3.9 (checked at startup).

## Prerequisites

* Amazon EKS Cluster
* AWS Load Balancer Controller installed (Gateway API demos also need the Gateway API CRDs installed)
* Credentials to access the EKS cluster, usually set up via `KUBECONFIG` - the kubernetes
  client reads the same kubeconfig `kubectl` does

No AWS credentials are needed here: these demos only create Kubernetes objects and let
the already-installed controller reconcile them into AWS load balancers.

## Deploy all 4 demos at once

```bash
./deploy_demos.py
```

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
