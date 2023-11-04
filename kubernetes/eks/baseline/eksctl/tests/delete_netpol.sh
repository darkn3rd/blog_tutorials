#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

## cleanup
MANIFESTS=(04-client 03-frontend 02-backend 01-management-ui 00-namespace)
APP_URL=https://docs.projectcalico.org/v3.5/getting-started/kubernetes/tutorials/stars-policy/manifests/

for MANIFEST in ${MANIFESTS[*]}; do 
  kubectl delete --filename $APP_URL/$MANIFEST.yaml
done
