# EKSCTL with Existing VPC usign AWS CLI

## Instructions

```bash
export EKS_CLUSTER_NAME="mycluster"
export EKS_REGION="$(aws configure get region)"
export EKS_VERSION="1.35"

./create_eks_cluster.sh
```