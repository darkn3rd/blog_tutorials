IRSA_KEY="eks\\.amazonaws\\.com/role-arn"

helm repo add aws-ebs-csi-driver \
  https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

helm upgrade \
  --install aws-ebs-csi-driver \
  --namespace kube-system \
  --set "controller.serviceAccount.annotations.$IRSA_KEY=$ACCOUNT_ROLE_ARN_ECSI" \
  aws-ebs-csi-driver/aws-ebs-csi-driver
