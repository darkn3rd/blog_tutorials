# Stage 4: Demos Ready

Verifies the four demos under [`../../../cli/`](../../../cli/) each got a
load balancer actually provisioned by AWS LBC and that it's reachable —
checks the Kubernetes status field AWS LBC writes back (`.status.loadBalancer.ingress`
for Service/Ingress, `.status.addresses` for Gateway), then makes a real
HTTP request against it.

Controls (`controls/demos.rb`), one per demo:

| Control              | Demo                | Default namespace/name              |
|-----------------------|---------------------|--------------------------------------|
| `svc-nlb-demo-ready`  | `cli/01.svc_nlb`    | `demo-nlb` / `demo-nlb-app`          |
| `ing-alb-demo-ready`  | `cli/02.ing_alb`    | `default` / `demo-alb-app` (Host: `demo.example.com`) |
| `gw-nlb-demo-ready`   | `cli/03.gw_nlb`     | `demo-gwtcp` / `demo-nlb-gateway`    |
| `gw-alb-demo-ready`   | `cli/04.gw_alb`     | `default` / `demo-alb-gw` (Host: `demo.example.com`) |

Defaults match what each demo's own script creates; override with the
corresponding `*_NAMESPACE` / `*_NAME` / `*_HOST` env vars (see the top of
`controls/demos.rb`) if you deployed a demo somewhere else.

## Required environment variables

None required — only needs a working `KUBECONFIG`/cluster context, and the
demos already applied per their own `cli/0N.*/README.md`.

## Run

```bash
./run_tests.sh
```

Runs against `-t k8s://`.
