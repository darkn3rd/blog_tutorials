# AWS LBC Demos (Python)

This area explores methods to deploy Kubernetes applications using the Kuberentes API:

* Shell Exec (`exec_cli`) - python scripts orchestrate calling tools much in the same way a shell script would work.
* Direct methods use the official Kubernetes client (`kubernetes-python-client`)
  * API (`direct_api`) - uses Kubernetes API python classes to build Kubernetes objects
  * Embedded Srings (`direct_fstrings`) - uses manifests stored as multi-line fstrings that are then sent to Kuberentes API
  * Tempaltes (`direct_jinja2`) - uses external templated manfiest files with Jinja2 that are processed and then sent to the Kubernetes API. 

Four independent ways to deploy the same four demo scenarios from Python:

| | [`direct_api/`](direct_api/README.md) | [`direct_fstrings/`](direct_fstrings/README.md) | [`direct_jinja2/`](direct_jinja2/README.md) | [`exec_cli/`](exec_cli/README.md) |
| --- | --- | --- | --- | --- |
| Mechanism | `kubernetes` client | `kubernetes` client | `kubernetes` client | `subprocess` calling `kubectl` |
| Manifest source | Typed `V1Deployment`/`V1Service` objects for plain resources | Multiline f-string YAML, parsed to a dict | Jinja2 template files, rendered then parsed to a dict | Multiline f-string YAML piped to `kubectl apply -f -` |
| Custom resources (Gateway API, ...) | `DynamicClient` generic apply | `DynamicClient` generic apply | `DynamicClient` generic apply | `kubectl apply -f -` |
| Dependencies | `kubernetes`, `PyYAML` | `kubernetes`, `PyYAML` | `kubernetes`, `PyYAML`, `Jinja2` | None - just `kubectl` on `PATH` |

## Python Client Libraries and Frameworks

In the future I may explore other client libraries or frameworks to deploy demos.  Putting links to these if you are interested in exploring them. 

* Client Libraries
    * [pykube-ng](https://codeberg.org/hjacobs/pykube-ng) — A highly lightweight client tailored for simple scripts and basic cluster interactions.
    * [kr8s](https://github.com/kr8s-org/kr8s) — A simple, extensible Python client library for Kubernetes that feels familiar for folks who already know how to use kubectl
    * [kubernetes-python-client](https://github.com/kubernetes-client/python) — Official, comprehensive library that provides full access to all Kubernetes API endpoints, authentication mechanisms, and resource types.
* Higher Level Frameworks
    * [kopf](https://github.com/nolar/kopf) — A Python framework to write Kubernetes operators in just a few lines of code
    * [cdk8s](https://github.com/cdk8s-team/cdk8s) — Define Kubernetes native apps and abstractions using object-oriented programming
    * [Pulumi](https://github.com/pulumi/pulumi) — Infrastructure as Code in any programming language
       * [pulumi-kubernetes](https://github.com/pulumi/pulumi-kubernetes) — A Pulumi resource provider for Kubernetes to manage API resources and workloads in running clusters