eksctl create iamserviceaccount \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --namespace "kube-system" \
  --name "aws-load-balancer-controller" \
  --role-name $ROLE_NAME_ALBC \
  --attach-policy-arn $POLICY_ARN_ALBC \
  --approve
