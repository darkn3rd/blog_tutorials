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

