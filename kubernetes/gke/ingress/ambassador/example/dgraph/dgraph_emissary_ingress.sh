export DGRAPH_HOSTNAME_HTTP=${DGRAPH_HOSTNAME_HTTP:-"dgraph.local"}
export DGRAPH_RELEASE_NAME=${DGRAPH_RELEASE_NAME:-"dg"}

kubectl apply --namespace dgraph --filename - <<EOF
---
apiVersion: getambassador.io/v3alpha1
kind: Host
metadata:
  name: $DGRAPH_RELEASE_NAME-dgraph
spec:
  hostname: "*"
  requestPolicy:
    insecure:
      action: Route
---
apiVersion: getambassador.io/v3alpha1
kind: Listener
metadata:
  name: $DGRAPH_RELEASE_NAME-dgraph
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
  name: $DGRAPH_RELEASE_NAME-dgraph-http
spec:
  hostname: $DGRAPH_HOSTNAME
  prefix: /
  service: $DGRAPH_RELEASE_NAME-dgraph-alpha.dgraph:8080
---
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata:
  name: $DGRAPH_RELEASE_NAME-dgraph-grpc
spec:
  hostname: "*"
  prefix: /api.Dgraph/
  rewrite: /api.Dgraph/
  service: $DGRAPH_RELEASE_NAME-dgraph-alpha.dgraph:9080
  grpc: True
EOF

curl -sOL https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto
grpcurl -plaintext -proto api.proto grpc.dgraph.local:80 api.Dgraph/CheckVersion

kubectl get Listener,Mapping,Host