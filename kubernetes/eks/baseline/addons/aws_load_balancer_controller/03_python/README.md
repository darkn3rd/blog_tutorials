# AWS Load Balancer Controller Installer (Python)

Two independent ways to install the AWS Load Balancer Controller (LBC) from Python:

| | [`direct_api/`](direct_api/README.md) | [`exec_cli/`](exec_cli/README.md) |
| --- | --- | --- |
| Mechanism | `boto3` + `kubernetes` client (direct API calls) | `subprocess` calling `aws`/`kubectl`/`eksctl` |
| Dependencies | `boto3`, `kubernetes`, `PyYAML` (see `direct_api/requirements.txt`) | None - just the `aws`/`kubectl`/`eksctl` binaries on `PATH` |
| Tool choice | N/A - boto3 talks to the IAM/EKS APIs directly, so there's only one way to do it | `eksctl` or `aws-cli` |
| Best for | No local CLI dependencies beyond `helm`; direct API error messages | Reads as literally the same commands you'd run by hand, just scripted |

Pick whichever fits what you're doing - neither is "more correct" than the other.

## Don't cross install methods

Each tears down only what it itself created. `direct_api/`'s installer never uses eksctl or
CloudFormation, so its uninstaller has nothing to reconcile against a CloudFormation-owned
binding. `exec_cli/`'s installer can create eksctl/CloudFormation-owned resources (when using
the `eksctl` tool), so its uninstaller is CloudFormation-aware. Don't install with one and
uninstall with the other, or against a cluster whose AWS LBC binding was set up any other
way - each uninstaller only knows how to safely tear down what its own installer creates.

## See also

* [`direct_api/README.md`](direct_api/README.md) - boto3/kubernetes-client installer
* [`exec_cli/README.md`](exec_cli/README.md) - subprocess/CLI-wrapping installer
