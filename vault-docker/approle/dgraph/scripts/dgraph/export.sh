#!/usr/bin/env bash
command -v jq > /dev/null || \
  { echo "[ERROR]: 'grep' command not not found" 1>&2; exit 1; }
command -v curl > /dev/null || \
  { echo "[ERROR]: 'curl' command not not found" 1>&2; exit 1; }
[[ -z "$DGRAPH_TOKEN" ]] && { echo 'DGRAPH_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export DGRAPH_HTTP=${DGRAPH_HTTP:-"http://localhost:8080"}
export DGRAPH_CONFIG_DIR=${DGRAPH_CONFIG_DIR:-"./dgraph"}

# Construct export mutation query
cat << EOF > $DGRAPH_CONFIG_DIR/export.graphql
mutation {
  export(input: { format: "json" }) {
    response {
      message
      code
    }
  }
}
EOF

# Issue Export Operation
curl --silent \
  --header "Content-Type: application/graphql" \
  --header "X-Dgraph-AccessToken: $DGRAPH_TOKEN" \
  --request POST \
  --upload-file $DGRAPH_CONFIG_DIR/export.graphql \
  http://$DGRAPH_HTTP/admin | jq
