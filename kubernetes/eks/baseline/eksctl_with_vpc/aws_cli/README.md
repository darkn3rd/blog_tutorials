# EKSCTL with Existing VPC usign AWS CLI

## Instructions

```bash
export AWS_PROFILE="myprofile" # change
export EKS_CLUSTER_NAME="mycluster"
export EKS_REGION="$(aws configure get region)"
export EKS_VERSION="1.35"

# kubeconfig 
mkdir -p $HOME/.kube/aws/
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

# create network infrastructure
./create_eks_network
# create kubernetes cluster
./create_eks_cluster.sh
```