#!/usr/bin/env bash
command -v jq > /dev/null || \
  { echo "[ERROR]: 'jq' command not not found" 1>&2; exit 1; }
command -v curl > /dev/null || \
  { echo "[ERROR]: 'curl' command not not found" 1>&2; exit 1; }

export DGRAPH_HTTP=${DGRAPH_HTTP:"http://localhost:8080"}
[[ -z "$DGRAPH_TOKEN" ]] && { echo 'DGRAPH_TOKEN not specified. Aborting' 2>&1 ; exit 1; }

curl "$DGRAPH_HTTP/alter" --silent --request POST \
 --header "X-Dgraph-AccessToken: $DGRAPH_TOKEN" \
 --data $'
name: string @index(term) .
release_date: datetime @index(year) .
revenue: float .
running_time: int .
starring: [uid] .
director: [uid] .

type Person {
  name
}

type Film {
  name
  release_date
  revenue
  running_time
  starring
  director
}
' | jq
