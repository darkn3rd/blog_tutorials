# EKS with eksctl and VPC with AWS CLI

This example creates the EKS networking layer using AWS CLI, then creates the EKS cluster using `eksctl`.

The goal is to show the AWS resources normally hidden behind `eksctl create cluster`, while still using `eksctl` for the Kubernetes cluster itself.

> ⚠️ **DISCLAIMER**: This example is intended for learning purposes and is not production-ready. Running this example will create AWS resources that may incur charges.

## Network Infrastructure Requirements

If you have existing network infrastructure and cannot use the Terraform scripts, verify that the following requirements are met before creating the EKS cluster:

* VPC
  * DNS Hostnames enabled
  * DNS Resolution enabled

* Subnets
  * At least 2 subnets across 2 Availability Zones
  * Public subnet tags:
    * `kubernetes.io/role/elb = 1`
  * Private subnet tags:
    * `kubernetes.io/role/internal-elb = 1`

* Cluster Tags (recommended)
  * `kubernetes.io/cluster/{cluster_name} = shared`
    * or
  * `kubernetes.io/cluster/{cluster_name} = owned`

* Route Tables
  * Public subnets:
    * `0.0.0.0/0 -> Internet Gateway`
  * Private subnets:
    * `0.0.0.0/0 -> NAT Gateway`

* IP Address Capacity
  * Sufficient IP addresses must be available for nodes, pods, and load balancers.

* Security Controls
  * Worker nodes must be able to communicate with required AWS services such as EKS, EC2, STS, ECR, and S3.

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