# Stage 4: Demos Ready

Verifies the four demos under [`../../../eks_terraform_project/demos/`](../../../eks_terraform_project/demos/)
(either the `tf/` or `cli/` variant — both produce the same
namespaces/resource names) each got a load balancer actually provisioned by
AWS LBC and that it's reachable — checks the Kubernetes status field AWS LBC
writes back (`.status.loadBalancer.ingress` for Service/Ingress,
`.status.addresses` for Gateway), then makes a real HTTP request against it.

Controls (`controls/demos.rb`), one per demo:

| Control              | Demo                    | Default namespace/name                                    |
|-----------------------|-------------------------|-------------------------------------------------------------|
| `svc-nlb-demo-ready`  | Service/NLB             | `demo-nlb` / `demo-nlb-app`                                  |
| `ing-alb-demo-ready`  | Ingress/ALB             | `demo-alb` / `demo-alb-app` (Host: `demo.example.com`)       |
| `gw-nlb-demo-ready`   | Gateway+TCPRoute/NLB    | `demo-gwtcp` / `demo-gwtcp-app-gateway`                      |
| `gw-alb-demo-ready`   | Gateway+HTTPRoute/ALB   | `demo-gwhttp` / `demo-gwhttp-app-gw` (Host: `demo.example.com`) |

Defaults are copied from the `DEMOS` table at the top of
[`../../../eks_terraform_project/demos/test_demos.sh`](../../../eks_terraform_project/demos/test_demos.sh),
which is the actual source of truth for these values — if that table
changes, update the defaults in `controls/demos.rb` to match. Override with
the corresponding `*_NAMESPACE` / `*_NAME` / `*_HOST` env vars (see the top
of `controls/demos.rb`) if you deployed a demo somewhere else.

## Required environment variables

None required — only needs a working `KUBECONFIG`/cluster context, and the
demos already applied per
[`../../../eks_terraform_project/demos/README.md`](../../../eks_terraform_project/demos/README.md).

## Run

```bash
./run_tests.sh
```

Runs against `-t k8s://`.
