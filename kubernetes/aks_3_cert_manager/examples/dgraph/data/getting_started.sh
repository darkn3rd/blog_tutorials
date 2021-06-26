#!/bin/sh
set -x

curl "https://alpha.$AZ_DNS_DOMAIN/mutate?commitNow=true" --silent --request POST \
 --header  "Content-Type: application/rdf" \
 --data-binary @sw.rdf | jq

curl "https://alpha.$AZ_DNS_DOMAIN/alter" --silent --request POST \
  --data-binary @sw.schema | jq
