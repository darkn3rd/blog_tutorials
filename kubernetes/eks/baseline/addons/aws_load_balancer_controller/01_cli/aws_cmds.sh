create_iamserviceaccount() {
  # Extract the OIDC Provider URL
  OIDC_URL=$(aws eks describe-cluster \
    --name $EKS_CLUSTER_NAME \
    --region $EKS_REGION \
    --query "cluster.identity.oidc.issuer" \
    --output text
  )
  
  # Strip the "https://" prefix to get just the provider ID string
  OIDC_PROVIDER=$(echo $OIDC_URL | sed 's/https:\/\///')

  cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
  
  aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://trust-policy.json

  aws iam attach-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy

  rm trust-policy.json

}