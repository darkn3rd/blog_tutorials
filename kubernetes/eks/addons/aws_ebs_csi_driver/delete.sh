# unset ebs-sc
kubectl patch storageclass ebs-sc --patch \
  '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
# gp2 set to default
kubectl patch storageclass gp2 --patch \
  '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl delete storageclass ebs-sc
# remove components
helm delete "aws-ebs-csi-driver" --namespace "kube-system"

# delete IAM Role
eksctl delete iamserviceaccount \
  --name "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION
