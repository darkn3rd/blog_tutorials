

## Settings

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export POLICY_NAME_ALBC="AWSLoadBalancerControllerIAMPolicy"
export ROLE_NAME_ALBC="AmazonEKSLoadBalancerControllerRole"
export POLICY_ARN_ALBC="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME_ALBC"
```

## Verify

```bash
# verify role is created
aws iam get-role --role-name "$ROLE_NAME_ALBC"
# verify policy is attached to the role
aws iam list-attached-role-policies --role-name "$ROLE_NAME_ALBC"

# verify service account has annotation pointing to role
kubectl get sa aws-load-balancer-controller --namespace "kube-system" \
  --output jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

## Manual IRSA Process

```bash
OIDC_ID=$(aws eks describe-cluster \
  --name $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text \
  | cut -d '/' -f 5
)
aws iam list-open-id-connect-providers | grep $OIDC_ID | cut -d '"' -f4 | cut -d '/' -f4
cat >load-balancer-role-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/oidc.eks.region-code.amazonaws.com/id/$OIDC_ID"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.region-code.amazonaws.com/id/$OIDC_ID:aud": "sts.amazonaws.com",
                    "oidc.eks.region-code.amazonaws.com/id/$OIDC_ID:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                }
            }
        }
    ]
}
EOF

aws iam create-role \
  --role-name $ROLE_NAME_ALBC \
  --assume-role-policy-document file://"load-balancer-role-trust-policy.json"

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME_ALBC \
  --role-name $ROLE_NAME_ALBC
```


## Delete

```bash 
helm delete -n kube-system aws-load-balancer-controller
eksctl delete iamserviceaccount \
  --name "aws-load-balancer-controller" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION

# Verify IAM Role deletion
aws iam get-role --role-name "$ROLE_NAME_ALBC"
# Verify IAM Policy detached
aws iam list-attached-role-policies --role-name "$ROLE_NAME_ALBC"
# Detach policy if attached
aws iam  detach-role-policy --role-name "$ROLE_NAME_ALBC" --policy-arn $POLICY_ARN_ALBC
# Delete role
aws iam delete-role --role-name "$ROLE_NAME_ALBC"
# Delete servcie account
kubectl delete sa aws-load-balancer-controller --namespace "kube-system"
```