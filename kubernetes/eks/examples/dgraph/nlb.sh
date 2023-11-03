helm repo add "dgraph" "https://charts.dgraph.io"
helm repo update

helm install "dg" dgraph/dgraph \
  --namespace "dg-nlb" \
  --create-namespace \
  --values - <<EOF
zero:
  persistence:
    storageClass: ebs-sc
alpha:
  persistence:
    storageClass: ebs-sc
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing   
EOF
