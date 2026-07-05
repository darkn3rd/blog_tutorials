# AWS Load Balancer Controller Installer

This area provides an automated workflow to install the AWS Load Balancer Controller (LBC) onto an existing EKS cluster entirely from the command line.

The script supports two independent choices, which combine into four possible install paths:

* **Auth mechanism** — how the LBC pod gets AWS IAM permissions:
  * `irsa` (default) — IAM Roles for Service Accounts, via an OIDC federated trust and an annotated ServiceAccount.
  * `pod-identity` — EKS Pod Identity, via the `eks-pod-identity-agent` addon and a Pod Identity association.
* **Provisioning tool** — how the IAM/association resources are created:
  * `eksctl` (default) — delegates IRSA/Pod Identity setup to `eksctl`'s higher-level commands.
  * `aws-cli` — creates the IAM role, trust policy, and association directly via `aws iam` / `aws eks`.

Regardless of which combination you choose, the script also:
* Deploys the Gateway API CRDs (experimental channel) via `kubectl`.
* Deploys the AWS LBC Helm chart to the cluster via `helm`.

## Required Local Tools

The installation script runs an automated pre-flight validation to ensure the following binaries are available in your local execution path:

* `aws` - AWS Command Line Interface
* `kubectl` - Kubernetes cluster orchestrator tool
* `helm` - Kubernetes package manager
* `jq` - Command-line JSON processor
* `curl` - Used to fetch the base IAM policy document
* `eksctl` - required only when using the `eksctl` provisioning tool

## Required Credentials & Access

Before running the script, ensure you have active access to both endpoints:

* **AWS Access**: a valid, authenticated AWS session via `aws login` for designated Profile.
* **Kubernetes Access**: a working cluster connection, typically configured via your `KUBECONFIG` environment variable or standard kubeconfig file.

## Auth Prerequisites

Each auth mechanism has a hard prerequisite that the script checks before doing any work, and will exit with guidance if it's missing:

* `irsa` requires an IAM OIDC provider already associated with the cluster:
  ```bash
  eksctl utils associate-iam-oidc-provider \
    --cluster "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --approve
  ```
* `pod-identity` requires the `eks-pod-identity-agent` EKS addon:
  ```bash
  aws eks create-addon \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --addon-name eks-pod-identity-agent
  ```

## Required Environment Variables

It is highly recommended to manage these inputs using an environment file to keep your workspace organized and repeatable.

```bash
# Create the environment file
cat <<EOF > inputs.env
export AWS_PROFILE="myuser"
export EKS_CLUSTER_NAME="mycluster"
export EKS_REGION="us-east-2"
EOF

# Source the variables into your active terminal session
source inputs.env
```

## Install AWS Load Balancer Controller

Run the script passing the provisioning tool as the first argument and the auth mechanism as the second. Both arguments are optional and default to `eksctl` and `irsa` respectively.

```bash
./install_aws_lbc.sh [tool] [auth]
```

| tool      | auth          | Result                                                          |
|-----------|---------------|------------------------------------------------------------------|
| `eksctl`  | `irsa`        | `eksctl create iamserviceaccount` (default; same as no args)     |
| `eksctl`  | `pod-identity`| `eksctl create podidentityassociation`                           |
| `aws-cli` | `irsa`        | Native `aws iam` role/trust-policy + annotated ServiceAccount     |
| `aws-cli` | `pod-identity`| Native `aws iam` role/trust-policy + `aws eks create-pod-identity-association` |

```bash
# Default: eksctl + IRSA
./install_aws_lbc.sh
./install_aws_lbc.sh eksctl irsa

# eksctl + Pod Identity
./install_aws_lbc.sh eksctl pod-identity

# aws-cli + IRSA
./install_aws_lbc.sh aws-cli irsa

# aws-cli + Pod Identity
./install_aws_lbc.sh aws-cli pod-identity
```

Run `./install_aws_lbc.sh --help` at any time to see this usage summary from the script itself.
