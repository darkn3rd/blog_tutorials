# AWS Load Balancer Controller (Terraform / IRSA)

This project provisions the AWS Load Balancer Controller (LBC) onto an
existing EKS cluster declaratively with Terraform, wiring up IAM Roles for
Service Accounts (IRSA) instead of running the imperative steps by hand.

## Architecture

The `module "load_balancer_controller"` ([`modules/load_balancer_controller/main.tf`](modules/load_balancer_controller/main.tf))
composes two submodules:

* [`lbc_irsa`](modules/load_balancer_controller/lbc_irsa) — looks up the
  cluster's IAM OIDC provider, fetches the upstream IAM policy document, and
  creates the `AWSLoadBalancerControllerIAMPolicy` policy + IRSA trust role.
* [`lbc_install`](modules/load_balancer_controller/lbc_install) — creates the
  annotated Kubernetes ServiceAccount, applies the Gateway API CRDs (plus AWS
  LBC's own Gateway CRD extensions), and installs the Helm release, using the
  role ARN from `lbc_irsa`.

## Required Local Tools

* `terraform` >= 1.6
* `aws` CLI — used for the AWS provider's credential chain, not invoked directly
* Terraform providers (fetched automatically by `terraform init`, no manual install needed):
  `aws` (~> 6.0), `kubernetes` (~> 3.2), `helm` (~> 3.2), `http` (~> 3.0), `kubectl` (gavinbunney, >= 1.19.0)

## Required Credentials & Access

* **AWS Access**: a valid, authenticated AWS session via `aws login` for the
  designated profile — used by the `aws` provider.
* **Kubernetes Access**: a working `KUBECONFIG`. The `kubernetes`/`helm`
  providers actually authenticate directly via the cluster's endpoint/CA and
  a short-lived token from the `aws_eks_cluster_auth` data source
  ([`data.tf`](data.tf)) and don't need it — but the `kubectl` provider
  (used only for the Gateway API CRDs in `lbc_install`) has no such data
  source wired up and falls back to your local `KUBECONFIG`.

## Prerequisite: IRSA OIDC provider must already exist

`lbc_irsa`'s `data "aws_iam_openid_connect_provider" "target"` is a lookup,
not a creation — Terraform will fail if the cluster has no IAM OIDC provider
associated yet. Create it first if needed:

```bash
eksctl utils associate-iam-oidc-provider --cluster "$EKS_CLUSTER_NAME" --region "$EKS_REGION" --approve
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

# Create the tfvars file (substitute your own cluster name/region/version,
# or export EKS_CLUSTER_NAME/EKS_REGION first and this will pick them up)
cat <<EOF > terraform.tfvars
eks_cluster_name = "${EKS_CLUSTER_NAME:?set EKS_CLUSTER_NAME or edit this value}"
eks_region       = "${EKS_REGION:?set EKS_REGION or edit this value}"
eks_version      = "1.36"
EOF
```

`chart_version` (Helm chart version, default `"3.4.0"`) and
`use_experimental_gateway_api` (default `true`) can also be set in
`terraform.tfvars` — see [`variables.tf`](variables.tf) and
[`modules/load_balancer_controller/variables.tf`](modules/load_balancer_controller/variables.tf).

## Install AWS Load Balancer Controller

```bash
terraform init
terraform apply
```

This creates, in order: the IAM policy + IRSA role (`lbc_irsa`), then the
annotated ServiceAccount, Gateway API CRDs, and the
`aws-load-balancer-controller` Helm release (`lbc_install`).

## Outputs

* `role_arn` — ARN of the IAM role assumed by the controller's ServiceAccount
* `helm_release_name` — name of the deployed Helm release

## Cleanup

```bash
terraform destroy
```
