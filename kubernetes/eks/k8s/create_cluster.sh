# Base Cluster
eksctl create cluster \
  --version $EKS_VERSION \
  --region $EKS_REGION \
  --name $EKS_CLUSTER_NAME \
  --nodes 3

# OIDC Provider
eksctl utils associate-iam-oidc-provider \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --approve
