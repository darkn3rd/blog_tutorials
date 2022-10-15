kubectl get secret \
  --namespace consul consul-ca-cert \
  -o jsonpath="{.data['tls\.crt']}" \
  | base64 --decode > ca.pem
