# EKS with eksctl

This is the simplest example in the series.

Using a single command, `eksctl` can provision the VPC, networking infrastructure, and EKS cluster required to run Kubernetes on AWS. This approach is ideal for learning, experimentation, demonstrations, and quickly evaluating new EKS features.

The goal of this example is to introduce Amazon EKS and `eksctl` while minimizing the amount of infrastructure configuration required.

> ⚠️ **DISCLAIMER**: This example is intended for learning purposes and is not production-ready. The networking and cluster configuration are largely managed by eksctl defaults. Running this example will create AWS resources that may incur charges.

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

The commands below will provision an EKS cluster and configure access using the `KUBECONFIG` environment variable.

By default, `eksctl` installs:

- EKS Control Plane
- Managed Node Group
- Add-ons:
  - CoreDNS
  - kube-proxy
  - Amazon VPC CNI
  - Metrics Server

> ⚠️ **IMPORTANT**: The simple eksctl deployment attaches the VPC CNI policy to the node IAM role. This works, but it grants broad EC2 networking permissions at the node level. In the Terraform-native example, we instead assign the VPC CNI permissions through Pod Identity, limiting those permissions to the VPC CNI service account.

```bash
export AWS_PROFILE="myuser"
EKS_CLUSTER_NAME="mycluster"
EKS_REGION="$(aws configure get region --profile "$AWS_PROFILE")"

# setup Kubernetes Configuration to a separate file
mkdir -p $HOME/.kube/aws/
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

# create K8S Cluster
eksctl create cluster --name $EKS_CLUSTER_NAME --region $EKS_REGION --version 1.36
```

## Optional Enhancements

The default cluster is sufficient for basic experimentation. The following optional components provide capabilities commonly required by real-world workloads.

### OIDC Provider 

The OIDC provider enables IAM Roles for Service Accounts (IRSA), which are required by many AWS-integrated applications such as the AWS Load Balancer Controller.

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster $EKS_CLUSTER_NAME \
  --approve
```

### Pod Identity Agent 

The Pod Identity Agent enables Kubernetes service accounts to access AWS resources using EKS Pod Identity.

```bash
eksctl create addon \
  --cluster $EKS_CLUSTER_NAME \
  --name eks-pod-identity-agent
```

### EBS CSI

The EBS CSI Driver allows Kubernetes PersistentVolumes to be dynamically provisioned from Amazon EBS.

```bash
eksctl create addon \
  --cluster $EKS_CLUSTER_NAME \
  --name aws-ebs-csi-driver
```

## Cleanup

```bash
eksctl delete cluster --name $EKS_CLUSTER_NAME --region $EKS_REGION
```