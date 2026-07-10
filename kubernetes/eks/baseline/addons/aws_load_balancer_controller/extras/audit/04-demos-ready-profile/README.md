# Stage 4: Demos Ready

Verifies four representative workloads (Service/NLB, Ingress/ALB,
Gateway+TCPRoute/NLB, Gateway+HTTPRoute/ALB) each got a load balancer
actually provisioned by AWS LBC and that it's reachable — checks the
Kubernetes status field AWS LBC writes back
(`.status.loadBalancer.ingress` for Service/Ingress, `.status.addresses`
for Gateway), then makes a real HTTP request against it. This only checks
state -- it doesn't deploy the workloads itself; deploy them however you
like first, using whatever namespaces/names you want (see below for how to
point the controls at them).

Controls (`controls/demos.rb`), one per demo:

| Control              | Demo                    | Default namespace/name                                    |
|-----------------------|-------------------------|-------------------------------------------------------------|
| `svc-nlb-demo-ready`  | Service/NLB             | `demo-nlb` / `demo-nlb-app`                                  |
| `ing-alb-demo-ready`  | Ingress/ALB             | `demo-alb` / `demo-alb-app` (Host: `demo.example.com`)       |
| `gw-nlb-demo-ready`   | Gateway+TCPRoute/NLB    | `demo-gwtcp` / `demo-gwtcp-app-gateway`                      |
| `gw-alb-demo-ready`   | Gateway+HTTPRoute/ALB   | `demo-gwhttp` / `demo-gwhttp-app-gw` (Host: `demo.example.com`) |

The defaults above are just that -- defaults, set at the top of
`controls/demos.rb`. Override with the corresponding `*_NAMESPACE` /
`*_NAME` / `*_HOST` env vars (see the top of that file) if you deployed a
demo under different names.

## Required environment variables

None required — only needs a working `KUBECONFIG`/cluster context, and the
four workloads already deployed somewhere reachable from it (under the
default names above, or your own via the env var overrides).

## Run

```bash
./run_tests.sh
```

Runs against `-t k8s://`.
