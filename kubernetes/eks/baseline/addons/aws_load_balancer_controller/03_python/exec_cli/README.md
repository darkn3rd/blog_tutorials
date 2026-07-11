# AWS Load Balancer Controller Installer (Python, CLI-wrapping)

Installs the AWS Load Balancer Controller (LBC) onto an existing EKS cluster by calling
the `aws`, `kubectl`, and `eksctl` CLI tools via `subprocess` - a Python-scripted version
of running those commands by hand.

`install_aws_lbc.py` takes two arguments:

* **tool** — which CLI provisions the IAM binding:
  * `eksctl` (default) — delegates IRSA/Pod Identity setup to `eksctl`'s higher-level
    commands.
  * `aws-cli` — creates the IAM role, trust policy, and association directly via
    `aws iam`/`aws eks`.
* **auth** — the authentication mechanism:
  * `irsa` (default) — IAM Roles for Service Accounts, via an OIDC federated trust and an
    annotated ServiceAccount.
  * `pod-identity` — EKS Pod Identity, via the `eks-pod-identity-agent` addon and a Pod
    Identity association.

Regardless of tool/auth choice, `install_aws_lbc.py` also applies the Gateway API CRDs
(experimental channel) and installs the AWS LBC Helm chart.

## No third-party Python dependencies

Every call in this directory shells out to `aws`, `kubectl`, `eksctl`, or `helm` - there's
no boto3, no kubernetes client, nothing to `pip install`. Just standard library (`subprocess`,
`argparse`, `json`) plus those four binaries on your `PATH`.

## IAM naming is scoped per cluster

The IAM policy this creates is named `AWSLoadBalancerControllerIAMPolicy-<cluster>` (see
`lib/naming.py`) rather than a fixed name - IAM policy names live in a single namespace
shared by the whole AWS account, so a fixed name would have every cluster in the account
fight over the same policy, and since uninstalling deletes the policy unconditionally, a
second cluster's uninstall would delete the first cluster's policy out from under it.
`uninstall_aws_lbc.py` computes the same scoped name from `$EKS_CLUSTER_NAME`, so install
and uninstall always agree on which policy is theirs.

The IAM **role** is only explicitly named this way on the `aws-cli` tool path
(`AmazonEKSLoadBalancerControllerRole-<cluster>`) - on the `eksctl` tool path, eksctl
generates its own uniquely-named role via CloudFormation, so there's no fixed name to
collide in the first place.

## Required Local Tools

```
aws       AWS Command Line Interface
kubectl   Kubernetes cluster orchestrator tool
helm      Kubernetes package manager
eksctl    required only when using the eksctl tool
```

Checked automatically at startup; the script exits with a clear message listing anything
missing.

## Required Credentials & Access

* **AWS Access**: a valid, authenticated AWS session via `aws login` for the designated
  profile.
* **Kubernetes Access**: a working cluster connection, typically via your `KUBECONFIG`
  environment variable or standard kubeconfig file.

## Auth Prerequisites

Each auth mechanism has a hard prerequisite that the script checks before doing any work,
and will exit with guidance if it's missing:

* `irsa` requires an IAM OIDC provider already associated with the cluster.
* `pod-identity` requires the `eks-pod-identity-agent` EKS addon.

## Required Environment Variables

```bash
cat <<EOF > inputs.env
export AWS_PROFILE="myuser"
export EKS_CLUSTER_NAME="mycluster"
export EKS_REGION="us-east-2"
EOF

source inputs.env
```

## Install AWS Load Balancer Controller

```bash
./install_aws_lbc.py [tool] [auth]
```

```bash
# Default: eksctl + IRSA
./install_aws_lbc.py
./install_aws_lbc.py eksctl irsa

# eksctl + Pod Identity
./install_aws_lbc.py eksctl pod-identity

# aws-cli + IRSA
./install_aws_lbc.py aws-cli irsa

# aws-cli + Pod Identity
./install_aws_lbc.py aws-cli pod-identity
```

Run `./install_aws_lbc.py --help` at any time to see this usage summary.

## Uninstall

```bash
./uninstall_aws_lbc.py
```

Self-detects whichever auth mode was used (IRSA annotation vs. Pod Identity association)
and whether eksctl/CloudFormation owns the binding, then tears it down the matching way:
via `eksctl delete` if eksctl owns it (mutating a CloudFormation-owned role directly would
desync the stack's tracked state from live AWS state), or via direct IAM API calls
otherwise. Deprovisions any AWS load balancers the controller created first, polling with
a bounded timeout and forcing stuck Kubernetes finalizers as a last resort.

**Only run this against a cluster set up by this directory's `install_aws_lbc.py`.**

## Layout

```
exec_cli/
  install_aws_lbc.py
  uninstall_aws_lbc.py
  lib/
    python_version.py   # Python >= 3.9 guard
    errors.py             # shared die()
    log.py                  # UTC-timestamped output
    run.py                    # subprocess wrapper (run/run_ok/run_json/run_streamed)
    naming.py                 # cluster-scoped IAM role/policy names
```
