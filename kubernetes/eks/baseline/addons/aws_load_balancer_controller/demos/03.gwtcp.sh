kubectl create namespace demo-gwtcp
kubectl config set-context --current --namespace=demo-gwtcp

kubectl create deployment demo-gwtcp-app \
  --image=nginx:alpine
kubectl expose deployment demo-gwtcp-app --port=80

kubectl apply -f 03.gwtcp.yaml


kubectl get gateway demo-gwtcp-app
kubectl get gatewayclass demo-gwtcp-app -o yaml

kubectl describe gateway demo-gwtcp-app
kubectl get tcproute demo-gwtcp-app -o yaml
export GW_NLB=$(kubectl get gateway demo-gwtcp-app -o jsonpath='{.status.addresses[0].value}')

k get all,gateway,tcproute