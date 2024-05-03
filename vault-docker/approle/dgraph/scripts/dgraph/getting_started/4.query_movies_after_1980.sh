#!/usr/bin/env bash
command -v jq > /dev/null || \
  { echo "[ERROR]: 'jq' command not not found" 1>&2; exit 1; }
command -v curl > /dev/null || \
  { echo "[ERROR]: 'curl' command not not found" 1>&2; exit 1; }

export DGRAPH_HTTP=${DGRAPH_HTTP:-"http://localhost:8080"}
[[ -z "$DGRAPH_TOKEN" ]] && { echo 'DGRAPH_TOKEN not specified. Aborting' 2>&1 ; exit 1; }

curl "$DGRAPH_HTTP/query" --silent --request POST \
  --header "Content-Type: application/dql" \
  --header "X-Dgraph-AccessToken: $DGRAPH_TOKEN" \
  --data $'
{
    me(func: allofterms(name, "Star Wars"), orderasc: release_date) 
     @filter(ge(release_date, "1980")) {
        name
        release_date
        revenue
        running_time
        director { name }
        starring (orderasc: name) { name }
    }
}
' | jq .data
