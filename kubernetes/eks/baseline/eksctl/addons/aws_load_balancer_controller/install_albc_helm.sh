# add AWS LB Controller (NLB/ALB) helm charts
helm repo add "eks" "https://aws.github.io/eks-charts"

# download charts
helm repo update

helm install \
  aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace "kube-system" \
  --set clusterName=$EKS_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
