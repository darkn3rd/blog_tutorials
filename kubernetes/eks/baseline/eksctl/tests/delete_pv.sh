#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

kubectl delete pod app --namespace "pv-test"
kubectl delete pvc pv-claim --namespace "pv-test"
kubectl delete ns "pv-test"