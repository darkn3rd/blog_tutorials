# AWS LBC Demos (Python)

Two independent ways to deploy the same four demo scenarios from Python:

| | [`direct_api/`](direct_api/README.md) | [`exec_cli/`](exec_cli/README.md) |
| --- | --- | --- |
| Mechanism | `kubernetes` client (direct API calls) | `subprocess` calling `kubectl` |
| Dependencies | `kubernetes`, `PyYAML` (see `direct_api/requirements.txt`) | None - just `kubectl` on `PATH` |

Pick whichever fits what you're doing - neither is "more correct" than the other. Don't
bring up both against the same cluster at once (see `../README.md`).

## See also

* [`direct_api/README.md`](direct_api/README.md) - kubernetes-client-based demos
* [`exec_cli/README.md`](exec_cli/README.md) - subprocess/kubectl-wrapping demos
