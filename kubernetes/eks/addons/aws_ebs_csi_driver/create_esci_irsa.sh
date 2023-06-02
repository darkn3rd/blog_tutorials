# AWS IAM role bound to a Kubernetes service account
eksctl create iamserviceaccount \
  --name "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --attach-policy-arn $POLICY_ARN_ESCI \
  --role-only \
  --role-name $ROLE_NAME_ECSI \
  --approve
