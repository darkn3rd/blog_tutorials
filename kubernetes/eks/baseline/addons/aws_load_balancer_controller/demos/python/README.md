# AWS LBC Demos (Python)

Four independent ways to deploy the same four demo scenarios from Python:

| | [`direct_api/`](direct_api/README.md) | [`direct_fstrings/`](direct_fstrings/README.md) | [`direct_jinja2/`](direct_jinja2/README.md) | [`exec_cli/`](exec_cli/README.md) |
| --- | --- | --- | --- | --- |
| Mechanism | `kubernetes` client | `kubernetes` client | `kubernetes` client | `subprocess` calling `kubectl` |
| Manifest source | Typed `V1Deployment`/`V1Service` objects for plain resources | Multiline f-string YAML, parsed to a dict | Jinja2 template files, rendered then parsed to a dict | Multiline f-string YAML piped to `kubectl apply -f -` |
| Custom resources (Gateway API, ...) | `DynamicClient` generic apply | `DynamicClient` generic apply | `DynamicClient` generic apply | `kubectl apply -f -` |
| Dependencies | `kubernetes`, `PyYAML` | `kubernetes`, `PyYAML` | `kubernetes`, `PyYAML`, `Jinja2` | None - just `kubectl` on `PATH` |

`direct_api/`, `direct_fstrings/`, and `direct_jinja2/` all call the Kubernetes API the same
way (the official `kubernetes-python-client`) and differ only in how the manifest content
itself is produced. `exec_cli/` is the odd one out - it shells out to `kubectl` instead of
calling the API directly.

Pick whichever fits what you're doing - none is "more correct" than the others. Don't
bring up more than one against the same cluster at once (see `../README.md`).

## See also

* [`direct_api/README.md`](direct_api/README.md) - typed SDK objects
* [`direct_fstrings/README.md`](direct_fstrings/README.md) - embedded f-string YAML
* [`direct_jinja2/README.md`](direct_jinja2/README.md) - Jinja2 template files
* [`exec_cli/README.md`](exec_cli/README.md) - subprocess/kubectl-wrapping
