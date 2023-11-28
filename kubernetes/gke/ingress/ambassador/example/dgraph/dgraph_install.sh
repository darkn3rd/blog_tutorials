export DGRAPH_ALLOW_LIST=${DGRAPH_ALLOW_LIST:-"0.0.0.0/0"}
export DGRAPH_RELEASE_NAME=${DGRAPH_RELEASE_NAME:-"dg"}

helm install $DGRAPH_RELEASE_NAME dgraph/dgraph \
  --namespace dgraph \
  --create-namespace \
  --values -  <<EOF
zero:
  persistence:
    storageClass: premium-rwo
    size: 10Gi
alpha:
  configFile:
    config.yaml: |
      security:
        whitelist: ${DGRAPH_ALLOW_LIST}
  persistence:
    storageClass: premium-rwo
    size: 30Gi
EOF
