#!/usr/bin/env bash
command -v grep > /dev/null || \
  { echo "[ERROR]: 'grep' command not not found" 1>&2; exit 1; }
command -v curl > /dev/null || \
  { echo "[ERROR]: 'curl' command not not found" 1>&2; exit 1; }

[[ -z "$DGRAPH_ADMIN_USER" ]] && { echo 'DGRAPH_ADMIN_USER not specified. Aborting' 2>&1 ; exit 1; }
[[ -z "$DGRAPH_ADMIN_PSWD" ]] && { echo 'DGRAPH_ADMIN_PSWD not specified. Aborting' 2>&1 ; exit 1; }

export DGRAPH_HTTP=${DGRAPH_HTTP:-"http://localhost:8080"}

export DGRAPH_TOKEN=$(curl --silent \
  --request POST \
  --data "{
    \"userid\": \"$DGRAPH_ADMIN_USER\", 
    \"password\": \"$DGRAPH_ADMIN_PSWD\", 
    \"namespace\": 0 
}" \
  http://$DGRAPH_HTTP/login | grep -oP '(?<=accessJWT":")[^"]*'
)

echo $DGRAPH_TOKEN > .dgraph.token