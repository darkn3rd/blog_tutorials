# AWS Load Balancer Controller Installer (Python)

This area explores methods to install the AWS Load Balancer Controller (LBC) using Python:

* Command Line Tools (`exec_cli`) - this python script will run in a similar way to a shell scripts and use CLI tools to interact with either AWS API or Kubernetes API 
* Direct API (`direct_api`) - this python script will interact with the client APIs directly.


| | [`direct_api/`](direct_api/README.md) | [`exec_cli/`](exec_cli/README.md) |
| --- | --- | --- |
| Mechanism | `boto3` + `kubernetes` client (direct API calls) | `subprocess` calling `aws`/`kubectl`/`eksctl` |
| Dependencies | `boto3`, `kubernetes`, `PyYAML` (see `direct_api/requirements.txt`) | None - just the `aws`/`kubectl`/`eksctl` binaries on `PATH` |
| Tool choice | N/A - boto3 talks to the IAM/EKS APIs directly, so there's only one way to do it | `eksctl` or `aws-cli` |
| Best for | No local CLI dependencies beyond `helm`; direct API error messages | Reads as literally the same commands you'd run by hand, just scripted |

## Don't cross install methods

Each tears down only what it itself created. The Direct API (`direct_api`) installer will never use `eksctl` or
CloudFormation, so its uninstaller has nothing to reconcile against a CloudFormation-owned
binding. 

However, Command Line Tools (`exec_cli`) installer can create eksctl/CloudFormation-owned resources (when using the `eksctl` tool), so its uninstaller is CloudFormation-aware. 

Don't install with one and uninstall with the other, or against a cluster whose AWS LBC binding was set up any other way, as each uninstaller only knows how to safely tear down what its own installer creates.

