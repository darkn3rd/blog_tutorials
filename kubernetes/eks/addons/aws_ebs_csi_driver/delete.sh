eksctl delete iamserviceaccount \
  --name "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME
