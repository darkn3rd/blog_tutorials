# AWS Load Balancer Controller Demos

Two independent ways to exercise the same 4 scenarios against a cluster with the AWS
Load Balancer Controller installed: a Service of type `LoadBalancer` (NLB), an `Ingress`
(ALB), and Gateway API with a `TCPRoute` (NLB) or `HTTPRoute` (ALB).

| | [`cli/`](cli/README.md) | [`tf/`](tf/README.md) |
| --- | --- | --- |
| Mechanism | Plain `kubectl` / manifests | Terraform |
| State | None - re-run scripts to reconcile | Terraform state (`terraform.tfstate`) |
| Bring up one demo | Run that demo's walkthrough directory manually | `terraform apply -target="module.<name>"` |
| Bring up all 4 | `./create_demos.sh` | `terraform apply` |
| Tear down | `./clean_demos.sh` | `terraform destroy` |
| Best for | Learning step-by-step, or a quick one-off check | Repeatable setup/teardown, keeping it in sync with the rest of this repo's IaC |

Pick whichever fits what you're doing - neither is "more correct" than the other.

## Don't run both at once

Both approaches use the same namespace names by default (`demo-nlb`, `demo-alb`,
`demo-gwtcp`, `demo-gwhttp`). Bringing up `cli/`'s demos while `tf/`'s are also up (or vice
versa) targets the same namespaces from two unmanaged sources - `terraform apply` may
fail trying to create resources `cli/create_demos.sh` already created (or Terraform's
state may drift if `clean_demos.sh` deletes something Terraform thinks it owns). Use one
or the other against a given cluster at a time.

## Testing

[`test.sh`](test.sh) works against either - it only depends on the resources actually
existing in the cluster, not on how they got there:

```bash
./test.sh
```

Waits for each demo's load balancer address to appear, waits for DNS to resolve, then
curls it. Reports PASS/FAIL per demo with bounded timeouts (won't hang forever if AWS
never finishes provisioning).

## See also

* [`cli/README.md`](cli/README.md) - kubectl-based demos (scripted or manual walkthrough)
* [`tf/README.md`](tf/README.md) - Terraform-based demos
