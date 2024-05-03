#!/usr/bin/env bash
command -v jq > /dev/null || \
  { echo "[ERROR]: 'jq' command not not found" 1>&2; exit 1; }
command -v curl > /dev/null || \
  { echo "[ERROR]: 'curl' command not not found" 1>&2; exit 1; }

export DGRAPH_HTTP=${DGRAPH_HTTP:-"http://localhost:8080"}
[[ -z "$DGRAPH_TOKEN" ]] && { echo 'DGRAPH_TOKEN not specified. Aborting' 2>&1 ; exit 1; }

curl "$DGRAPH_HTTP/mutate?commitNow=true" --silent --request POST \
 --header "X-Dgraph-AccessToken: $DGRAPH_TOKEN" \
 --header  "Content-Type: application/json" \
 --data $'
{
  "set": [
    {"uid": "_:luke","name": "Luke Skywalker", "dgraph.type": "Person"},
    {"uid": "_:leia","name": "Princess Leia", "dgraph.type": "Person"},
    {"uid": "_:han","name": "Han Solo", "dgraph.type": "Person"},
    {"uid": "_:lucas","name": "George Lucas", "dgraph.type": "Person"},
    {"uid": "_:irvin","name": "Irvin Kernshner", "dgraph.type": "Person"},
    {"uid": "_:richard","name": "Richard Marquand", "dgraph.type": "Person"},
    {
      "uid": "_:sw1",
      "name": "Star Wars: Episode IV - A New Hope",
      "release_date": "1977-05-25",
      "revenue": 775000000,
      "running_time": 121,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:lucas"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:sw2",
      "name": "Star Wars: Episode V - The Empire Strikes Back",
      "release_date": "1980-05-21",
      "revenue": 534000000,
      "running_time": 124,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:irvin"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:sw3",
      "name": "Star Wars: Episode VI - Return of the Jedi",
      "release_date": "1983-05-25",
      "revenue": 572000000,
      "running_time": 131,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:richard"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:st1",
      "name": "Star Trek: The Motion Picture",
      "release_date": "1979-12-07",
      "revenue": 139000000,
      "running_time": 132,
      "dgraph.type": "Film"
    }
  ]
}
' | jq
