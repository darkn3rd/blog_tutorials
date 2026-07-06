# Stage 2: Bindings Ready

Verifies `install_aws_lbc.sh`'s preparation steps actually succeeded, for
whichever `tool`/`auth` combination was used to run it (see
[`../../../install_aws_lbc.sh`](../../../install_aws_lbc.sh)).

Controls:

* `controls/gateway_crds.rb` — `gateway-api-standard-crds`,
  `gateway-api-experimental-crds`, `aws-lbc-gateway-extensions-crds`. Moved
  here from stage 1 (`01-cluster-ready-profile`) since CRD presence is a
  "prep succeeded" concern, not a pre-flight one.
* `controls/iam_binding.rb`:
  * `lbc-iam-policy-attached` — the `AWSLoadBalancerControllerIAMPolicy`
    exists and is attached to `AmazonEKSLoadBalancerControllerRole`.
  * `lbc-iam-binding-ready` — auto-detects the auth mode from the
    controller's ServiceAccount (an `eks.amazonaws.com/role-arn` annotation
    means IRSA; its absence means Pod Identity) and checks the matching
    side of the binding.

This profile ships a custom resource, `aws_eks_pod_identity_association`
(`libraries/aws_eks_pod_identity_association.rb`), since `inspec-aws`
doesn't cover Pod Identity associations.

## Required environment variables

* `EKS_CLUSTER_NAME` — name of the target cluster
* `AWS_PROFILE` — must already be an active, authenticated profile

## Run

```bash
./run_tests.sh
```

Runs everything against a single `-t k8s://` target: `aws_*` resources talk
to AWS directly via the SDK regardless of `-t`, while `k8s_*` resources need
the `k8s://` transport to reach the cluster.
