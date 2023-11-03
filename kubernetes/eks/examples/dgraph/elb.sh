helm repo add "dgraph" "https://charts.dgraph.io"
helm repo update

helm install "dg" dgraph/dgraph \
  --namespace "dg-elb" \
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
EOF

