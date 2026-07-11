# AWS Load Balancer Controller Demos

Three independent ways to exercise the same four scenarios against a cluster with the AWS
Load Balancer Controller installed: a Service of type `LoadBalancer` (NLB), an `Ingress`
(ALB), and Gateway API with a `TCPRoute` (NLB) or `HTTPRoute` (ALB).

| | [`cli/`](cli/README.md) | [`python/`](python/README.md) | [`tf/`](tf/README.md) |
| --- | --- | --- | --- |
| Mechanism | Plain `kubectl` / manifests | Python (two ways - see `python/README.md`) | Terraform |
| State | None - re-run scripts to reconcile | None - re-run scripts to reconcile | Terraform state (`terraform.tfstate`) |
| Bring up one demo | Run the script or manifest in that demo directory | Not split out per-demo - run the full script | `terraform apply -target="module.<name>"` |
| Bring up all 4 | `cd cli && ./deploy_demos.sh` | `cd python/direct_api && ./deploy_demos.py` (or `python/exec_cli`) | `cd tf && terraform apply` |
| Tear down | `cd cli && ./clean_demos.sh` | `cd python/direct_api && ./clean_demos.py` (or `python/exec_cli`) | `cd tf && terraform destroy` |
| Best for | Learning step-by-step, or a quick one-off check | If you'd rather read/extend Python than bash | Repeatable setup/teardown, keeping it in sync with the rest of this repo's IaC |

Pick whichever fits what you're doing - none is "more correct" than the others.

## Don't run more than one at once

All three approaches use the same namespace names by default (`demo-nlb`, `demo-alb`,
`demo-gwtcp`, `demo-gwhttp`). Bringing up more than one approach's demos against the same
cluster targets the same namespaces from multiple unmanaged sources - `terraform apply`
may fail trying to create resources `cli/deploy_demos.sh` or one of `python/`'s
`deploy_demos.py` variants already created (or Terraform's state may drift if one of the others deletes something
Terraform thinks it owns). Use exactly one against a given cluster at a time.

## Testing

[`test_demos.sh`](test_demos.sh) works against any of the three: it only depends on the resources actually
existing in the cluster, not on how they got there:

```bash
./test_demos.sh
```

Waits for each demo's load balancer address to appear, waits for DNS to resolve, then
curls it. Reports PASS/FAIL per demo with bounded timeouts (won't hang forever if AWS
never finishes provisioning).

## See also

* [`cli/README.md`](cli/README.md) - kubectl-based demos (scripted or manual walkthrough)
* [`python/README.md`](python/README.md) - Python-based demos (kubernetes client or kubectl-wrapping)
* [`tf/README.md`](tf/README.md) - Terraform-based demos
