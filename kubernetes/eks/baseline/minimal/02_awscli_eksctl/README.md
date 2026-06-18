# EKS with eksctl and VPC with AWS CLI

This example creates the EKS networking layer using AWS CLI, then creates the EKS cluster using `eksctl`.

The goal is to show the AWS resources normally hidden behind `eksctl create cluster`, while still using `eksctl` for the Kubernetes cluster itself.

> ⚠️ **DISCLAIMER**: This example is intended for learning purposes and is not production-ready. Running this example will create AWS resources that may incur charges.

## Setup Profile

```bash
EKS_ACCOUNT_ID="123456789012" # Change to your account id
EKS_REGION="us-east-2"

mkdir -p ~/.aws

cat <<EOF >> ~/.aws/config
[profile myuser]
login_session = arn:aws:iam::$EKS_ACCOUNT_ID:user/myuser
region = $EKS_REGION
EOF

export AWS_PROFILE=myuser
aws login
aws sts get-caller-identity
```

This should show:

```json
{
    "UserId": "AIDA0123456789EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/myuser"
}
```

## Create Cluster

The commands below provision the VPC networking resources, generate a `cluster.yaml`, create the EKS cluster, and configure access using the `KUBECONFIG` environment variable.

> ℹ️ **NOTE**: Resource identifiers are stored in `vpc-outputs.env` as the network infrastructure is created. The cleanup script uses this file to locate and remove the AWS resources created by the example.

This example creates a more complete EKS configuration than the simple one-command deployment, including:

- OIDC Provider (IRSA)
- Pod Identity
- Persistent Storage with EBS CSI

```bash
export AWS_PROFILE="myuser"
EKS_CLUSTER_NAME="mycluster"
EKS_REGION="$(aws configure get region --profile "$AWS_PROFILE")"

# setup Kubernetes Configuration to a separate file
mkdir -p $HOME/.kube/aws/
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

# create network infrastructure
./create_eks_network.sh
# create kubernetes cluster
./create_eks_cluster.sh
```

Unlike the previous example with `01_eksctl`, the VPC resources are created and managed explicitly rather than being generated automatically by `eksctl`.

## Cleanup

```bash
eksctl delete cluster --name $EKS_CLUSTER_NAME --region $EKS_REGION
./cleanup_eks_network.sh
```