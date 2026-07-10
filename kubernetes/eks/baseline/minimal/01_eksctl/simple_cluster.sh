#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"
: "${EKS_VERSION:?EKS_VERSION is required}"

mkdir -p ~/.kube/aws
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

eksctl create cluster \
  --name $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --version "$EKS_VERSION"


# The OIDC provider enables IAM Roles for Service Accounts (IRSA), 
# which are required by many AWS-integrated applications such as 
# the AWS Load Balancer Controller.
eksctl utils associate-iam-oidc-provider \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --approve

# The Pod Identity Agent enables Kubernetes service accounts 
# to access AWS resources using EKS Pod Identity.
eksctl create addon \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --name eks-pod-identity-agent

# The EBS CSI Driver allows Kubernetes PersistentVolumes to be
# dynamically provisioned from Amazon EBS.
eksctl create addon \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --name aws-ebs-csi-driver
