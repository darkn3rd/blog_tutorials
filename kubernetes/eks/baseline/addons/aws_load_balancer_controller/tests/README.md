# LBC install/uninstall test matrix

Automates verification across every install-method x auth-mode combination
this project supports, plus targeted negative scenarios reproducing bugs
already found and fixed by hand (stale IAM policy collisions, CloudFormation
ownership drift, class-name-dependent Gateway API deletion, finalizer-lock
hangs). Each phase drives the same 7-function contract regardless of how LBC
was installed, so `install_aws_lbc.sh`/`uninstall_aws_lbc.sh` and the
Terraform [`irsa/`](../irsa)/[`podid/`](../podid) roots are exercised through
identical validation/demo/cleanup steps.

## Layout

```
tests/
  matrix.yaml          # cases, tiers, suites
  run_matrix.sh         # orchestrator - see Usage below
  lib/
    yaml.sh              # matrix.yaml reader (yq-based)
    log.sh                # per-phase log capture + summary.json
    contract.sh            # install_lbc/validate_lbc/deploy_demos/... - dispatches per install_method
  phases/
    00_provision_cluster.sh   # run-scoped (once per invocation, not per case)
    01_preflight.sh .. 08_uninstall_lbc.sh   # per-case
    09_destroy_cluster.sh     # run-scoped
  suites/
    negative_collision.sh
    negative_extra_lbs.sh
    negative_finalizer_lock.sh
  logs/                 # gitignored, created at runtime - see Logs below
```

Every phase script can be run standalone (it just reads env vars) or
orchestrated by `run_matrix.sh`.

## Required Local Tools

`aws`, `kubectl`, `helm`, `jq`, `yq` (mikefarah/yq v4), `terraform`, `eksctl`, `python3`.

## Required Environment Variables

```bash
export CLUSTER_PROVISIONER_ROOT="/path/to/kubernetes/eks/baseline/minimal"
export AWS_PROFILE="myprofile"
```

`CLUSTER_PROVISIONER_ROOT` is the directory containing
`01_eksctl/02_awscli_eksctl/03_terraform_eksctl/04_terraform_native/05_terraform_modules`
— machine-specific, not stored in `matrix.yaml`. Only `05_terraform_modules`
is implemented today (see [Cluster provisioning](#cluster-provisioning)
below); the other four are clearly-marked stubs.

`EKS_REGION`/`EKS_CLUSTER_NAME`/`KUBECONFIG` are **not** set by hand — phase
00 generates a unique cluster per run and writes all three (plus which
`.tfvars` file it used) to `logs/cluster.env`, which every other phase reads.

## Usage

Two different workflows, matching two different ways you'd actually use this:

### Ad-hoc / discrete testing — `--case`

```bash
./run_matrix.sh --case cli-eksctl-irsa
./run_matrix.sh --case terraform-podid
./run_matrix.sh --destroy-cluster        # when you're done for the day
```

Provisions a cluster **only if none is currently up and reachable**
(`logs/cluster.env` plus a live `kubectl cluster-info` check — a stale file
left over from an already-destroyed cluster doesn't fool it) and **never**
destroys it afterward. Run `--case` repeatedly against the same cluster
without paying the ~15-20 minute provision cost every time. `--destroy-cluster`
is the explicit teardown command for whenever you're actually done.

### Batch runs — `--all` / `--tier`

```bash
./run_matrix.sh --all
./run_matrix.sh --tier smoke
./run_matrix.sh --tier release           # kick off, check back later/overnight
```

Always provisions a fresh cluster first and destroys it after every case
finishes, unless `--keep-cluster` is passed (skips both, reuses whatever's
already up — requires `logs/cluster.env` to already exist).

### Recommended first run

A full cluster provision/destroy cycle is not fast or free (~15-20 min up,
~10-15 min down, real AWS cost the whole time). Before trusting a full
`--tier`/`--all` run:

```bash
./phases/00_provision_cluster.sh          # validate provisioning + kubeconfig alone
kubectl get nodes                          # confirm it's actually up
./run_matrix.sh --tier smoke --keep-cluster   # exercise both eksctl-CLI cases
./phases/09_destroy_cluster.sh            # tear down once satisfied
```

## `matrix.yaml`

Three sections:

* **`cluster`** — which provisioner (`cluster.provisioner`, maps to a
  `CLUSTER_PROVISIONER_ROOT` subdirectory) and default `eks_version`/`eks_region`.
* **`cases`** — the 12 `install_method` (`cli-eksctl` | `cli-aws` | `terraform`
  | `python-direct-api` | `python-exec-cli-eksctl` | `python-exec-cli-awscli`)
  x `auth_mode` (`irsa` | `pod-identity`) combinations.
* **`tiers`** — named `(cases, suites)` presets for `--tier`. `cases: all` and
  `suites: all` both expand at run time — `all` cases means every entry
  under `cases:`, `all` suites means every `suites/*.sh` file (not a
  hardcoded list), so adding a new suite file makes it eligible for any tier
  requesting `all` without editing `matrix.yaml`.

```yaml
tiers:
  smoke:         { cases: [cli-eksctl-irsa, cli-eksctl-podid], suites: [positive] }
  full-positive: { cases: all, suites: [positive] }
  negative:      { cases: [...], suites: [negative-collision, negative-extra-lbs, negative-finalizer-lock] }
  release:       { cases: all, suites: all }
```

`positive` isn't a suite script — it's the always-run baseline flow
(phases 01-05, 07-08). `--case`/`--all` without `--tier` run `positive` only;
negative suites only run when a tier's `suites:` list requests them.

## The contract (`lib/contract.sh`)

```
install_lbc <install_method> <auth_mode>
validate_lbc
deploy_demos
validate_demos
cleanup_demos
uninstall_lbc <install_method> <auth_mode>
verify_clean <install_method>
```

Every phase script calls into this — phases themselves never branch on
`install_method`. Dispatch summary:

| Function | `cli-eksctl` / `cli-aws` | `terraform` | `python-direct-api` | `python-exec-cli-eksctl` / `python-exec-cli-awscli` |
|---|---|---|---|---|
| `install_lbc` | `install_aws_lbc.sh <eksctl\|aws-cli> <auth_mode>` | `terraform apply` in [`irsa/`](../irsa) or [`podid/`](../podid) | `03_python/direct_api/install_aws_lbc.py <auth_mode>` (boto3/kubernetes-client) | `03_python/exec_cli/install_aws_lbc.py <eksctl\|aws-cli> <auth_mode>` (subprocess calling `aws`/`kubectl`/`eksctl`) |
| `uninstall_lbc` | `uninstall_aws_lbc.sh` | `terraform destroy` in the same root | `03_python/direct_api/uninstall_aws_lbc.py` | `03_python/exec_cli/uninstall_aws_lbc.py` (self-detects auth mode and eksctl/CloudFormation ownership - one function serves both `exec-cli` tool variants) |
| `validate_lbc` / `deploy_demos` / `validate_demos` / `cleanup_demos` | same for all four — install-method-agnostic (`scripts/validate_*.sh`, `demos/cli/*.sh`) |
| `verify_clean` | independent oracle, not a reuse of any installer's internals — asserts zero demo namespaces, Gateway API objects/CRDs, Helm release, AWS load balancers, and the IAM policy/role, by kind rather than by name wherever the name is user-choosable. IAM policy/role naming is install-method-aware: fixed names for `cli-*`/`terraform`, cluster-scoped names (`AWSLoadBalancerControllerIAMPolicy-<cluster>`, and for `python-direct-api`/`python-exec-cli-awscli` also `AmazonEKSLoadBalancerControllerRole-<cluster>`) for every `python-*` method - see `03_python/*/lib/naming.py`. `python-exec-cli-eksctl` reuses the same CloudFormation stack names as `cli-eksctl`, since eksctl's own naming convention doesn't care which wrapper invoked it. |

`python-direct-api` needs a Python venv (`.venv`) with its `requirements.txt`
installed - `install_lbc`/`uninstall_lbc` create and populate it automatically
on first use (`ensure_python_venv()` in `lib/contract.sh`) if it doesn't
already exist, the same way `install_lbc_terraform()` calls `terraform init`
every time. `python-exec-cli-*` has no pip dependencies at all (subprocess +
stdlib only), so it just uses system `python3` directly.

**Never** run one install method's uninstaller against another method's
case. `uninstall_aws_lbc.sh` owns its resources via CloudFormation (when
eksctl-created) or direct IAM calls, `terraform destroy` owns them via
Terraform state, and the Python uninstallers assume whatever their own
matching installer created. Mixing any of these reintroduces the exact
ownership-drift bug class this project already hit once with CloudFormation.

`.tfvars` files for both cluster provisioning and the `irsa`/`podid` roots
are written per-run/per-case (`test_<datestamp>.tfvars`,
`test_<case-name>.tfvars`) and passed via `-var-file=`, never as
`terraform.tfvars` directly — both directories already have their own
`terraform.tfvars` for manual/non-test use, and overwriting that in place
would clobber it silently.

## Logs

```
logs/
  cluster.env                # written by phase 00, read by everything else
  00-provision-cluster.log
  09-destroy-cluster.log
  <case-name>/
    preflight.log  install.log  validate-lbc.log  demos.log
    validate-demos.log  negative.log  cleanup.log  uninstall.log
    summary.json
```

Each run overwrites the previous run's logs for a given case. `summary.json`:

```json
{
  "case": "cli-eksctl-irsa",
  "install_method": "cli-eksctl",
  "auth_mode": "irsa",
  "suites": ["negative-collision"],
  "result": "pass",
  "phases": {
    "install": { "result": "pass", "duration_s": 42, "log": "install.log" },
    ...
  }
}
```

## Negative suites (`suites/`)

* **`negative_collision.sh`** — for `cli-*` and every `python-*` case,
  temporarily pushes a bad IAM policy version and confirms
  `validate_iam_policy.sh` catches it (the ARN it pushes onto is
  install-method-aware, matching whichever policy-naming convention that
  case actually used). For `terraform` cases, detaches the policy from the
  Terraform-managed role out-of-band and confirms
  `terraform plan -detailed-exitcode` reports drift.
* **`negative_extra_lbs.sh`** — deploys demo-shaped resources with randomly
  suffixed names/namespaces (not the 4 canonical ones). For `cli-*` and
  `python-*` cases they're left for phase 08's wholesale uninstall to catch
  (the actual regression test); for `terraform` cases the suite cleans up
  after itself, since `terraform destroy` only knows about its own state.
* **`negative_finalizer_lock.sh`** — force-removes the Helm release before
  deprovisioning, stranding a Gateway with a live finalizer, then asserts
  `uninstall_lbc` self-heals within a hard timeout instead of hanging.
  **Known limitation**: `terraform destroy`'s reverse-apply order (Helm
  before CRDs, same ordering that caused the original bug) has no
  self-healing equivalent to `uninstall_aws_lbc.sh`'s
  `force_clear_stuck_finalizers`. A `terraform-*` case failing this suite is
  a legitimate, expected finding pointing at that gap, not a suite defect —
  the timeout wrapper exists precisely so it surfaces as a bounded failure
  instead of hanging the whole run.

## Cluster provisioning

`phases/00_provision_cluster.sh` / `09_destroy_cluster.sh` dispatch on
`cluster.provisioner` in `matrix.yaml` to a subdirectory under
`CLUSTER_PROVISIONER_ROOT`. Only `terraform-modules` (→
`05_terraform_modules`) is implemented; `eksctl`, `awscli-eksctl`,
`terraform-eksctl`, and `terraform-native` are stubs that error clearly
(`... has no provisioning logic yet ...`) until filled in, following
`provision_terraform_modules()`/`destroy_terraform_modules()` as the
template.

## Extending

* **New case**: add an entry under `cases:` in `matrix.yaml` — no script
  changes needed as long as `install_method` is one of the six
  `lib/contract.sh` already dispatches.
* **New tier**: add an entry under `tiers:` — `cases`/`suites` can be
  explicit lists or `all`.
* **New negative suite**: add `suites/<name>.sh` (source `lib/contract.sh`,
  exit non-zero on failure); it's automatically eligible for any tier
  requesting `suites: all`, or add it by name to a specific tier.
* **New cluster provisioner**: fill in the corresponding case in
  `phases/00_provision_cluster.sh` and `09_destroy_cluster.sh`.

## See also

* [`../README.md`](../README.md) — the AWS Load Balancer Controller addon this framework tests
* [`../01_cli/README.md`](../01_cli/README.md) — the bash CLI install/uninstall
* [`../03_python/README.md`](../03_python/README.md) — the Python install/uninstall (`direct_api`/`exec_cli`)
* [`../demos/`](../demos) — the demo apps `deploy_demos`/`validate_demos`/`cleanup_demos` drive
