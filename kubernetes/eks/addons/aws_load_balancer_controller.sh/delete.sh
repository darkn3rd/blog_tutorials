eksctl delete iamserviceaccount \
  --name "aws-load-balancer-controller" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION

helm delete \
  aws-load-balancer-controller \
  --namespace "kube-system"

helm install \
  aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace "kube-system" \
  --set clusterName=$EKS_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
