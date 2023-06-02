# deploy application
kubectl create namespace "httpd-ing"
kubectl create deployment httpd \
  --image "httpd" \
  --replicas 3 \
  --port 80 \
  --namespace "httpd-ing"
#
kubectl expose deployment httpd \
  --port 80 \
  --target-port 80 \
  --namespace "httpd-ing"
#
# provision application load balancer
kubectl create ingress alb-ingress \
  --class "alb" \
  --rule "/=httpd:80" \
  --annotation "alb.ingress.kubernetes.io/scheme=internet-facing" \
  --annotation "alb.ingress.kubernetes.io/target-type=ip" \
  --namespace "httpd-ing"
