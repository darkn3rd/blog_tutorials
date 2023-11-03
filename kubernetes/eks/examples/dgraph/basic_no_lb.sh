helm repo add "dgraph" "https://charts.dgraph.io"
helm repo update

helm install "ex" dgraph/dgraph \
  --namespace "dgraph" \
  --create-namespace \
  --set zero.persistence.storageClass=ebs-sc \
  --set alpha.persistence.storageClass=ebs-sc

helm install --name my-release hazelcast/hazelcast -f - <<EOF
service:
  type: LoadBalancer
EOF