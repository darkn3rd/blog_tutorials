# Stage 2: Bindings Ready

Verifies the LBC preparation steps actually succeeded: the Gateway API CRDs
are installed, and the controller's ServiceAccount is genuinely bound to an
IAM role that grants it the permissions it needs. This only checks state --
it doesn't provision, install, or deploy anything, and doesn't assume any
particular tool or workflow produced that state.

Controls:

* `controls/gateway_crds.rb` — `gateway-api-standard-crds`,
  `gateway-api-experimental-crds`, `aws-lbc-gateway-extensions-crds`. Moved
  here from stage 1 (`01-cluster-ready-profile`) since CRD presence is a
  "prep succeeded" concern, not a pre-flight one.
* `controls/iam_binding.rb`:
  * `lbc-iam-binding-ready` — auto-detects the auth mode from the
    controller's ServiceAccount (an `eks.amazonaws.com/role-arn` annotation
    means IRSA; its absence means Pod Identity) and checks the matching
    side of the binding.
  * `lbc-iam-policy-attached` — does **not** check for a specific policy
    name either (see below) — it fetches the canonical upstream IAM policy
    (plus the Gateway API statement amendment AWS LBC needs for
    ALBGatewayAPI/NLBGatewayAPI support), and verifies each resulting
    statement — Effect, Action set, Resource set, and Condition, not just
    action names — is granted somewhere across whatever policies are
    actually attached to the discovered role. A policy that happens to be
    named `AWSLoadBalancerControllerIAMPolicy` but grants the wrong
    permissions fails this; a policy under any other name that grants the
    right ones passes.

`iam_binding.rb` does **not** hardcode the controller's IAM role name or
its policy name, because neither is predictable in general -- different
tools name the role differently, and some auto-generate a random name
entirely. Instead, the role is discovered from the ServiceAccount's binding
itself: an `eks.amazonaws.com/role-arn` annotation (the standard EKS Pod
Identity Webhook contract that any IRSA-based tool sets identically, not
something each one invents independently) if present, or an EKS Pod
Identity association otherwise. The attached policy is then discovered off
that role directly, rather than assumed by name.

This profile ships two custom resources, since `inspec-aws` doesn't cover
either:
* `aws_eks_pod_identity_association` (`libraries/aws_eks_pod_identity_association.rb`)
* `k8s_custom_resource_definition` (`libraries/k8s_custom_resource_definition.rb`)
  — see that file's comment for why `k8sobject` can't be used for CRDs.

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
