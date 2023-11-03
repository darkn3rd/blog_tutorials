#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

## Deploy manifests
MANIFESTS=(00-namespace 01-management-ui 02-backend 03-frontend 04-client)
APP_URL=https://docs.projectcalico.org/v3.5/getting-started/kubernetes/tutorials/stars-policy/manifests/

for MANIFEST in ${MANIFESTS[*]}; do 
  kubectl apply -f $APP_URL/$MANIFEST.yaml
done


## Apply Initial Network Policies 
DENY_URL=https://docs.projectcalico.org/v3.5/getting-started/kubernetes/tutorials/stars-policy/policies/default-deny.yaml

kubectl apply --namespace client --filename $DENY_URL
kubectl apply --namespace stars --filename $DENY_URL


## Apply UI network policies
export ALLOW_URL=https://docs.projectcalico.org/v3.5/getting-started/kubernetes/tutorials/stars-policy/policies/

kubectl apply --filename $ALLOW_URL/allow-ui.yaml
kubectl apply --filename $ALLOW_URL/allow-ui-client.yaml


## Apply Backend allow pollicy
kubectl apply --filename $ALLOW_URL/backend-policy.yaml

## Apply Frontend allow policy
kubectl apply --filename $ALLOW_URL/frontend-policy.yaml
