# delete aws-load-balancer-controller
helm delete \
  aws-load-balancer-controller \
  --namespace "kube-system"

# delete IAM role
eksctl delete iamserviceaccount \
  --name "aws-load-balancer-controller" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION

# delete policy if no longer needed
aws iam delete-policy --policy-arn $POLICY_ARN_ALBC
