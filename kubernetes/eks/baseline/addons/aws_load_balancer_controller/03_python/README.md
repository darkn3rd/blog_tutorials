# AWS Load Balancer Controller Installer (Python)

Installs the AWS Load Balancer Controller (LBC) onto an existing EKS cluster using
**boto3** and the **kubernetes** Python client to call the AWS and Kubernetes APIs
directly, instead of shelling out to `aws`/`kubectl`/`eksctl`.

`install_aws_lbc.py` takes an **auth mode** argument:

* `irsa` (default) — IAM Roles for Service Accounts, via an OIDC federated
  trust and an annotated ServiceAccount.
* `pod-identity` — EKS Pod Identity, via the `eks-pod-identity-agent` addon
  and a Pod Identity association.

Regardless of auth mode, `install_aws_lbc.py` also:
* Applies the Gateway API CRDs (experimental channel) via the kubernetes
  client's server-side apply.
* Installs the AWS LBC Helm chart.

## The one exception: Helm

Everything else in this directory — IAM, EKS, ELBv2, CloudFormation,
ServiceAccounts, CRDs, Ingress/Service/Gateway objects — goes through boto3
or the kubernetes client with no subprocess calls at all. Helm is the single
deliberate exception: there is no official (or de facto standard) Python SDK
for Helm, so installing/uninstalling the chart still means invoking the
`helm` binary (see `lib/helm.py`). `helm` must be on your `PATH`.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Requires Python >= 3.9, checked at startup by every script; fails fast with
a clear message otherwise (see `lib/python_version.py`).

## Required Credentials & Access

* **AWS Access**: a valid, authenticated AWS session via `aws login` for the
  designated profile — boto3 reads the same `~/.aws/` credentials/config
  files the `aws` CLI does.
* **Kubernetes Access**: a working cluster connection via your `KUBECONFIG`
  environment variable or standard kubeconfig file — the kubernetes client
  reads the same kubeconfig `kubectl` does.

## Auth Prerequisites

Each auth mechanism has a hard prerequisite that the script checks before
doing any work, and will exit with guidance if it's missing:

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
./install_aws_lbc.py [auth]
```

```bash
# Default: IRSA
./install_aws_lbc.py
./install_aws_lbc.py irsa

# Pod Identity
./install_aws_lbc.py pod-identity
```

Run `./install_aws_lbc.py --help` at any time to see this usage summary.

## Uninstall

```bash
./uninstall_aws_lbc.py
```

Self-detects whichever auth mode was used (IRSA annotation vs. Pod Identity
association) and tears down the matching IAM binding, then the CRDs and
Helm release. Deprovisions any AWS load balancers the controller created
first, polling with a bounded timeout and forcing stuck Kubernetes
finalizers as a last resort.

**Only run this against a cluster set up by `install_aws_lbc.py`.** It never
touches CloudFormation — everything it creates is plain IAM/EKS API calls, no
CloudFormation stack involved, so it has nothing to reconcile against a
binding created by a different tool.

## Scripts

* `scripts/validate_eks_req.py` — pre-install cluster prerequisite checks
  (OIDC provider, Pod Identity addon, VPC CNI, subnet tagging).
* `scripts/validate_crds.py` — verify Gateway API CRDs are installed.
* `scripts/validate_iam_policy.py` — verify the IAM policy has every
  required statement (discovers the policy from the controller's
  ServiceAccount if `--policy-name` isn't given).
* `scripts/validate_auth.py` — verify the full auth chain end to end
  (ServiceAccount → role → policy attached → policy contents).
* `scripts/check_aws_lbc_status.py` — read-only survey of an existing
  install (auth mechanism, Gateway API readiness, Helm/controller
  versions).
* `scripts/delete_crds.py` — remove Gateway API CRDs, with a confirmation
  prompt and `--dry-run`.

Each takes `-h`/`--help` for its full flag list. Every validation script
checks live cluster/AWS state directly — none of them assume or care how the
controller was actually installed.

## Layout

```
03_python/
  requirements.txt
  install_aws_lbc.py
  uninstall_aws_lbc.py
  lib/
    python_version.py    # Python >= 3.9 guard
    errors.py             # shared die()
    log.py                 # UTC-timestamped output
    aws.py                  # boto3 helpers (IAM, EKS, ELBv2, CloudFormation, EC2, STS)
    k8s.py                   # kubernetes client helpers (generic by-kind operations via DynamicClient)
    helm.py                  # the one subprocess exception
    crd_lists.py              # CRD name lists (validate/delete)
    policy_definitions.py     # the expected IAM policy document
    policy_validation.py      # policy statement fingerprinting/diffing
    role_discovery.py         # find the IAM role/policy bound to a ServiceAccount
  scripts/
    validate_eks_req.py
    validate_crds.py
    validate_iam_policy.py
    validate_auth.py
    check_aws_lbc_status.py
    delete_crds.py
```

`lib/` is shared by both the top-level install/uninstall scripts and
everything under `scripts/`, since all of it lives in and is used only
within this directory.
