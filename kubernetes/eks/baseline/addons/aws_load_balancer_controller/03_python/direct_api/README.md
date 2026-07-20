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

## IAM naming is scoped per cluster, with collision detection

The IAM role and policy this creates are named `AmazonEKSLoadBalancerControllerRole-<cluster>`
and `AWSLoadBalancerControllerIAMPolicy-<cluster>` (see `lib/naming.py`) rather than a fixed
name. IAM role/policy names live in a single namespace shared by the whole AWS account —
unlike a Kubernetes ServiceAccount, which is already isolated per-cluster by being on a
separate API server. A fixed name would have every cluster in the account fight over the
same role, and since installing against an existing role overwrites its trust policy, a
second cluster's install would silently rebind (and a later uninstall would delete) the
first cluster's binding.

Scoping by cluster name avoids that in the common case, but a name is not a reservation —
some unrelated resource (hand-created, made by another tool, or left over from a torn-down
environment that reused the same cluster name) can already occupy the exact name this
installer would compute. `install_aws_lbc.py` handles that: `lib/aws.py`'s
`resolve_role_name()`/`resolve_policy_name()` check every existing candidate's ownership tag
(`aws-load-balancer-controller-installer/cluster`, set on every role/policy this installer
creates) before deciding whether to reuse it (a prior run of this installer against the same
cluster — safe, idempotent re-install) or skip it as a genuine collision and escalate to the
next candidate — a deterministic name derived from a short hash of `<cluster>#<attempt>`, the
same idea eksctl uses when it appends a generated suffix rather than failing outright. Up to
`naming.MAX_NAME_ATTEMPTS` (6) candidates are tried before giving up.

`uninstall_aws_lbc.py` can't simply recompute the attempt-0 name the way it used to — if
install escalated past a collision, that name was never used. Instead `lib/aws.py`'s
`find_owned_policy_arn()` walks the same candidate sequence checking the ownership tag,
discovering whichever candidate install actually landed on. (The IAM role doesn't need this:
uninstall always discovers it from the live ServiceAccount annotation or Pod Identity
association, not by recomputing a name, so it's collision-safe by construction.)

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
direct_api/
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
    naming.py                 # cluster-scoped IAM role/policy names
    crd_lists.py                # CRD name lists (validate/delete)
    policy_definitions.py       # the expected IAM policy document
    policy_validation.py        # policy statement fingerprinting/diffing
    role_discovery.py           # find the IAM role/policy bound to a ServiceAccount
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
