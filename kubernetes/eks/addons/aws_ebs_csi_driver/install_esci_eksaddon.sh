# Create Addon
eksctl create addon \
  --name "aws-ebs-csi-driver" \
  --cluster $EKS_CLUSTER_NAME \
  --region=$EKS_REGION \
  --service-account-role-arn $ACCOUNT_ROLE_ARN_ECSI \
  --force
