
kubectl get secret \
  --namespace consul consul-ca-cert \
  -o jsonpath="{.data['tls\.crt']}" \
  | base64 --decode > ca.pem

export CONSUL_HTTP_TOKEN=$(kubectl get \
  --namespace consul secrets/consul-bootstrap-acl-token \
  --template={{.data.token}} | base64 -d
)
