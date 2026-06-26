# EKS via eksctl | VPC via eksctl

This is the simplest example in the series.

Using a single command, `eksctl` can provision the VPC, networking infrastructure, and EKS cluster required to run Kubernetes on AWS. This approach is ideal for learning, experimentation, demonstrations, and quickly evaluating new EKS features.

The goal of this example is to introduce Amazon EKS and `eksctl` while minimizing the amount of infrastructure configuration required.

> ⚠️ **DISCLAIMER**: This example is intended for learning purposes and is not production-ready. The networking and cluster configuration are largely managed by eksctl defaults. Running this example will create AWS resources that may incur charges.

## 1. Setup Profile

Configure a local AWS CLI profile using browser-based console authentication to acquire secure, short-lived temporary credentials:

```bash
# Define your environment vars
EKS_ACCOUNT_ID="123456789012" # Change to your account id
EKS_REGION="us-east-2"

mkdir -p ~/.aws

# Append the login configuration block
cat <<EOF >> ~/.aws/config
[profile myuser]
login_session = arn:aws:iam::$EKS_ACCOUNT_ID:user/myuser
region = $EKS_REGION
EOF

# Authenticate and activate the session
aws login --profile "myuser"
export AWS_PROFILE="myuser"

# Verify your active identity context
aws sts get-caller-identity
```

A successful connection will return your authenticated identity metadata:

```json
{
    "UserId": "AIDA0123456789EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/myuser"
}
```

## 2. Create Cluster

The deployment scripts provision an EKS cluster and automatically configure local context tracking using an isolated `KUBECONFIG` path.

By default, eksctl automatically initializes:

* EKS Control Plane (Fully managed Kubernetes API master)
* Managed Node Group (EC2 worker compute instances)
* Core Add-ons: CoreDNS, kube-proxy, Amazon VPC CNI, and Metrics Server

### Initialize Environment Variables
Run these commands in your active shell to seed the environment before executing the creation scripts:

```bash
export AWS_PROFILE="myuser"
EKS_CLUSTER_NAME="mycluster"
EKS_REGION="$(aws configure get region --profile "$AWS_PROFILE")"

# Isolate the Kubernetes configuration mapping to a dedicated file
mkdir -p $HOME/.kube/aws/
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"
```

### Option A: Create a Simple Cluster

This script provisions a basic 2-node cluster and applies runtime patches to configure IRSA, Pod Identity, and the EBS CSI storage driver.

> ⚠️ **SECURITY NOTE**: This simple deployment attaches the VPC CNI network policy directly to the shared node IAM Instance Profile. This grants broad, cluster-wide EC2 networking permissions at the underlying node layer.

```bash
./simple_cluster.sh
```

### Option B: Create a Secure Cluster

This script implements a more production-ready paradigm where the VPC CNI policy is scoped down and assigned exclusively to its specific Kubernetes service account using EKS Pod Identity.

```bash
./secure_cluster.sh
```

## Cleanup

To avoid recurring AWS infrastructure charges, completely tear down the provisioned EKS cluster and its underlying VPC network stack by running:

```bash
eksctl delete cluster --name $EKS_CLUSTER_NAME --region $EKS_REGION
```
