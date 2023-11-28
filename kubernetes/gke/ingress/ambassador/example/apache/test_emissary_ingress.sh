#!/usr/bin/env

TEST_EMISSARY_INGRESS_FQDN="emissary.ingress.test"

# deploy application 
kubectl create namespace "emissary-ingress-test"
kubectl create deployment httpd \
  --image "httpd" \
  --replicas 3 \
  --port 80 \
  --namespace "emissary-ingress-test"

# create proxy to deployment
kubectl expose deployment httpd \
  --port 80 \
  --target-port 80 \
  --type ClusterIP \
  --namespace "emissary-ingress-test"

kubectl apply --namespace emissary-ingress-test --filename - <<EOF
---
apiVersion: getambassador.io/v3alpha1
kind: Host
metadata:
  name:  emissary-ingress-test
spec:
  hostname: "*"
  requestPolicy:
    insecure:
      action: Route
---
apiVersion: getambassador.io/v3alpha1
kind: Listener
metadata:
  name:  emissary-ingress-test
spec:
  port: 8080
  protocol: HTTP
  securityModel: INSECURE
  hostBinding:
    namespace:
      from: SELF
---
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name:  emissary-ingress-test
spec:
  hostname: $TEST_EMISSARY_INGRESS_FQDN
  prefix: /
  service: http://httpd.emissary-ingress-test:80
EOF