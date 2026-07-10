# AWS Load Balancer Controller (Terraform / IRSA or Pod Identity)

This project installs the **AWS Load Balancer Controller** (**AWS LBC**) on an existing EKS cluster using **Terraform**. During installation it provisions the required AWS IAM resources and configures either **IAM Roles for Service Accounts** (**IRSA**) or **EKS Pod Identity** instead of performing the imperative steps by hand.

## Layout

There are two independent Terraform roots, one per IAM auth path. Pick
whichever matches how your cluster grants AWS permissions to pods, then run
Terraform from that directory:

* [`irsa/`](irsa) — uses IAM Roles for Service Accounts
* [`podid/`](podid) — uses EKS Pod Identity

Both roots compose the same shared building blocks from
[`modules/load_balancer_controller/`](modules/load_balancer_controller):

* [`lbc_setup`](modules/load_balancer_controller/lbc_setup) — thin wrapper
  that composes `lbc_auth` → `lbc_prep`. Exists purely so both can be applied
  (or targeted) as a single unit — see "Staged apply" below.
  * [`lbc_auth`](modules/load_balancer_controller/lbc_auth) — fetches the upstream IAM policy document and creates the IAM policy and IAM role, then associates the role with the controller's `ServiceAccount` via one of two mutually exclusive paths selected by its `auth_mode` variable:
    * `auth_mode = "irsa"` ([`irsa.tf`](modules/load_balancer_controller/lbc_auth/irsa.tf)) — looks up the cluster's IAM OIDC provider and builds an IRSA trust policy.
    * `auth_mode = "pod_identity"` ([`podid.tf`](modules/load_balancer_controller/lbc_auth/podid.tf)) — builds a trust policy for `pods.eks.amazonaws.com` and associates the role via `aws_eks_pod_identity_association`. Requires the EKS Pod Identity Agent addon to already be installed on the cluster.

  * [`lbc_prep`](modules/load_balancer_controller/lbc_prep) — creates the Kubernetes ServiceAccount (annotated with the role ARN only for IRSA) and applies the Gateway API CRDs (plus AWS LBC's own Gateway CRD extensions).
* [`lbc_install`](modules/load_balancer_controller/lbc_install) — installs
  the `aws-load-balancer-controller` Helm release, using the ServiceAccount
  name from `lbc_setup`.

Each root wires these together itself (`lbc_setup` → `lbc_install`), passing
the `auth_mode` that matches the root into `lbc_setup`.

## Required Local Tools

* `terraform` >= 1.6
* `aws` CLI — used for the AWS provider's credential chain, not invoked directly
* Terraform providers (installed automatically by `terraform init`):
  * `aws` (~> 6.0)
  * `kubernetes` (~> 3.2)
  * `helm` (~> 3.2)
  * `http` (~> 3.0)
  * `kubectl` (gavinbunney, >= 1.19.0)

## Required Credentials & Access

* **AWS Access**: a valid, authenticated AWS session via `aws login` for the
  designated profile — used by the `aws` provider.
* **Kubernetes Access**: a working `KUBECONFIG`. The `kubernetes` and `helm`
  providers authenticate directly using the cluster endpoint, CA certificate, and a short-lived token from `aws_eks_cluster_auth`. The kubectl provider (used only to install the Gateway API CRDs) instead uses your local `KUBECONFIG`.

The kubernetes and helm providers authenticate directly using the cluster endpoint, CA certificate, and a short-lived token from aws_eks_cluster_auth. The kubectl provider (used only to install the Gateway API CRDs) instead uses your local KUBECONFIG.

## Prerequisites

**IRSA root (`irsa/`)**: `lbc_auth`'s `data "aws_iam_openid_connect_provider" "target"`
is a lookup, not a creation — Terraform will fail if the cluster has no IAM
OIDC provider associated yet. Create it first if needed:

```bash
eksctl utils associate-iam-oidc-provider --cluster "$EKS_CLUSTER_NAME" --region "$EKS_REGION" --approve
```

**Pod Identity root (`podid/`)**: the EKS Pod Identity Agent addon must
already be installed on the cluster. Create it first if needed:

```bash
aws eks create-addon --cluster-name "$EKS_CLUSTER_NAME" --addon-name eks-pod-identity-agent --region "$EKS_REGION"
```

## Required Environment Variables & `terraform.tfvars`

```bash
# Create the environment file
cat <<EOF > inputs_tf.env
export AWS_PROFILE="myuser"
export EKS_CLUSTER_NAME="mycluster"
export EKS_REGION="us-east-2"
export KUBECONFIG="\$HOME/.kube/aws/\${EKS_REGION}.\${EKS_CLUSTER_NAME}.yaml"
EOF

source inputs_tf.env

# Create the tfvars file inside whichever root you're using (substitute your
# own cluster name/region/version, or export EKS_CLUSTER_NAME/EKS_REGION
# first and this will pick them up)
cat <<EOF > irsa/terraform.tfvars   # or podid/terraform.tfvars
eks_cluster_name = "${EKS_CLUSTER_NAME:?set EKS_CLUSTER_NAME or edit this value}"
eks_region       = "${EKS_REGION:?set EKS_REGION or edit this value}"
eks_version      = "1.36"
EOF
```

`chart_version` (Helm chart version, default `"3.4.0"`) can also be set in
`terraform.tfvars` — see each root's `variables.tf`. So can `role_name` /
`policy_name`, if you want something other than the defaults
(`"${eks_cluster_name}-aws-load-balancer-controller"` and
`"AWSLoadBalancerControllerIAMPolicy"`) — e.g. to run more than one instance
of this against the same AWS account, since those names aren't otherwise
segregated per environment/root the way state already is.

## Install AWS Load Balancer Controller

```bash
cd irsa   # or: cd podid
terraform init
terraform apply
```

The selected root installs **AWS LBC** by provisioning the required IAM resources, configuring the Kubernetes `ServiceAccount` and Gateway API CRDs, and finally deploying the Helm release.

* IRSA creates an IAM role with an OIDC trust policy and annotates the `ServiceAccount`.
* Pod Identity creates an EKS Pod Identity association instead of using `ServiceAccount` annotations.

## Staged apply

`lbc_setup` and `lbc_install` can be applied in two separate steps — handy
for running a verification pass (e.g. confirming the ServiceAccount, CRDs,
and IAM role/association look right) before installing the Helm release:

```bash
terraform apply -target="module.lbc_setup"
# ...run checks against the ServiceAccount / CRDs / IAM role here...
terraform apply -target="module.lbc_install"
```

The second command still re-evaluates `module.lbc_setup` (since
`lbc_install` depends on its outputs), but since nothing changed there it's a
no-op — only `lbc_install` actually applies.

## Outputs

* `role_arn` — ARN of the IAM role assumed/associated with the controller's ServiceAccount
* `helm_release_name` — name of the deployed Helm release

## Cleanup

```bash
terraform destroy
```
