# Stage 1: Cluster Ready

Verifies an EKS cluster has the AWS-side prerequisites `install_aws_lbc.sh`
needs *before* it runs at all. Corresponds to `verify_auth_prerequisites()`
and the discovery steps in [`../../../install_aws_lbc.sh`](../../../install_aws_lbc.sh).

Controls (`controls/aws_requirements.rb`):

* `eks-cluster-active` — the cluster exists, is `ACTIVE`, and runs a
  supported Kubernetes version.
* `eks-cluster-subnets-tagged` — at least one cluster subnet carries the
  `kubernetes.io/role/elb` discovery tag AWS LBC needs to place
  internet-facing load balancers.
* `eks-lbc-auth-mechanism-ready` — either an IRSA OIDC provider is
  associated with the cluster, or the `eks-pod-identity-agent` addon is
  installed (OR gate: only the missing mechanism is reported as failing).

This profile ships a small custom resource, `aws_eks_addon`
(`libraries/aws_eks_addon.rb`), since `inspec-aws` doesn't have one.

## Required environment variables

* `EKS_CLUSTER_NAME` — name of the target cluster
* `AWS_PROFILE` — must already be an active, authenticated profile (`run_tests.sh`
  exports its credentials into the shell via `aws configure export-credentials`)

## Run

```bash
./run_tests.sh
```

Runs against `-t aws://$AWS_REGION`. Uses `cinc-auditor` if it's on `PATH`,
otherwise falls back to `inspec` — the two are wire-compatible.
