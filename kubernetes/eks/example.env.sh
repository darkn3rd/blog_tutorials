# variables used to create EKS
export AWS_PROFILE="my-profile" # CHANGEME
export EKS_CLUSTER_NAME="my-cluster" # CHANGEME
export EKS_REGION="us-west-2" # change as needed
export EKS_VERSION="1.26" # change as needed

# KUBECONFIG variable
export KUBECONFIG=$HOME/.kube/$EKS_REGION.$EKS_CLUSTER_NAME.yaml

export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# used in automation
export POLICY_NAME_ALBC="AWSLoadBalancerControllerIAMPolicy"
export ROLE_NAME_ALBC="AmazonEKSLoadBalancerControllerRole"
export POLICY_ARN_ALBC="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME_ALBC"

export ROLE_NAME_ECSI="${EKS_CLUSTER_NAME}_EBS_CSI_DriverRole"
export ACCOUNT_ROLE_ARN_ECSI="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME_ECSI"
export POLICY_ARN_ESCI="arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
