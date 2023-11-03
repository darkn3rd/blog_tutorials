helm repo add "dgraph" "https://charts.dgraph.io"
helm repo update

# install helm chart
helm install "dg" dgraph/dgraph \
  --namespace "dg-alb" \
  --create-namespace \
  --values - <<EOF
zero:
  persistence:
    storageClass: ebs-sc
alpha:
  persistence:
    storageClass: ebs-sc
  service:
    type: ClusterIP
EOF

# create ingress
kubectl apply --namespace "dg-alb" --filename - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dg-dgraph-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - backend:
              service:
                name:  dg-dgraph-alpha
                port:
                  number: 8080
            pathType: ImplementationSpecific
            path: /*
EOF

