#!/usr/bin/env
# deploy application 
kubectl create namespace "ingress-test"
kubectl create deployment httpd \
  --image "httpd" \
  --replicas 3 \
  --port 80 \
  --namespace "ingress-test"

# create proxy to deployment
kubectl expose deployment httpd \
  --port 80 \
  --target-port 80 \
  --type ClusterIP \
  --namespace "ingress-test"

# provision application load balancer
kubectl create ingress httpd-ingress \
  --rule "ingress.test/=httpd:80" \
  --annotation "kubernetes.io/ingress.class=ambassador" \
  --class "ambassador" \
  --namespace "ingress-test"