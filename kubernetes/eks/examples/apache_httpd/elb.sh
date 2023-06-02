# deploy application
kubectl create namespace "httpd"
kubectl create deployment httpd \
  --image "httpd" \
  --replicas 3 \
  --port 80 \
  --namespace "httpd"
#
kubectl create service loadbalancer httpd \
  --tcp=80:80 \
  --namespace "httpd"
#
# provision application load balancer
kubectl create ingress alb-ingress \
  --class "alb" \
  --rule "/=httpd:80" \
  --annotation "alb.ingress.kubernetes.io/scheme=internet-facing" \
  --annotation "alb.ingress.kubernetes.io/target-type=ip" \
  --namespace "httpd-ing"
