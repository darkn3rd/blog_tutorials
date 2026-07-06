# Stage 2: Bindings Ready

Verifies the LBC preparation steps actually succeeded, regardless of which
install path produced them: [`../../../install_aws_lbc.sh`](../../../install_aws_lbc.sh)
(either `tool`/`auth` combination) or the
[Terraform IRSA module](../../../eks_terraform_project).

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
  * `lbc-iam-policy-attached` — the `AWSLoadBalancerControllerIAMPolicy`
    exists and is attached to whichever IAM role `lbc-iam-binding-ready`
    discovered.

`iam_binding.rb` does **not** hardcode the controller's IAM role name,
because it isn't predictable in general: `install_aws_lbc.sh`'s `aws-cli`
mode always names it `AmazonEKSLoadBalancerControllerRole`, and the
Terraform module names it `${eks_cluster_name}-aws-load-balancer-controller`
— but `install_aws_lbc.sh`'s `eksctl` mode (both `irsa` and `pod-identity`)
never passes `--role-name`, so eksctl auto-generates the role via
CloudFormation with a random suffix, with no fixed name at all to check
against. Instead, the role is discovered the same way
`check_aws_lbc_status.sh`'s `determine_auth_mode()` does: read off the
ServiceAccount's IRSA annotation (set identically by eksctl, the `aws-cli`
path, and the Terraform module — it's the standard EKS Pod Identity Webhook
contract, not something each tool invents independently), or off the Pod
Identity association if that annotation is absent.

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
