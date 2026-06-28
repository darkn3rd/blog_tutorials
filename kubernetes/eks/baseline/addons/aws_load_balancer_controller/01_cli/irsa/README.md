# AWS Load Balancer Controller (IRSA Method)

This area provides an automated workflow to install the AWS Load Balancer Controller (LBC) using IAM Roles for Service Accounts (IRSA) entirely from the command line.

The architecture coordinates four distinct toolchains to execute the installation sequentially:
* AWS CLI / eksctl: Provisions the required AWS IAM roles and policies, and establishes the secure OIDC trust relationship.
* kubectl: Deploys the core Gateway API Custom Resource Definitions (CRDs).
* Helm: Deploys AWS LBC to the Kubernetes Cluster.

## Required Local Tools

The installation script runs an automated pre-flight validation to ensure the following binaries are available in your local execution path:

* `aws` - AWS Command Line Interface
* `kubectl` - Kubernetes cluster orchestrator tool
* `helm` - Kubernetes package manager
* `jq` - Command-line JSON processor
* `eksctl` - cluster controller tool useful for automating IRSA setup (optional)

## Required Credentials & Access

Before running the script, ensure you have active access to both endpoints:

* **AWS Access**: a valid, authenticated AWS session via `aws login` for designated Profile.
* **Kubernetes Access**: a working cluster connection, typically configured via your `KUBECONFIG` environment variable or standard kubeconfig file.

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
Run the script by passing your preferred execution method as the first argument:

```bash
# Option A: Abstraction Mode (Uses eksctl for IRSA setup)
./install_aws_lbc.sh eksctl
# Note: Simply running './install_aws_lbc.sh' will also default to eksctl

# Option B: Native Mode (Uses pure aws-cli and kubectl for IRSA setup)
./install_aws_lbc.sh aws-cli
```