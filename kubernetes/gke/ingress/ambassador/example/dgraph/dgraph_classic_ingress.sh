export DGRAPH_HOSTNAME_HTTP=${DGRAPH_HOSTNAME_HTTP:-"dgraph.local"}
export DGRAPH_RELEASE_NAME=${DGRAPH_RELEASE_NAME:-"dg"}

kubectl apply --namespace dgraph --filename - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $DGRAPH_RELEASE_NAME-dgraph-ingress
  annotations:
    kubernetes.io/ingress.class: ambassador
spec:
  ingressClassName: ambassador
  rules:
    - http:
        paths:
          - backend:
              service:
                name:  $DGRAPH_RELEASE_NAME-dgraph-alpha
                port:
                  number: 8080
            pathType: ImplementationSpecific
            path: /
      host: $DGRAPH_HOSTNAME_HTTP
EOF
