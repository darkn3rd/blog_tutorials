#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

## cleanup
kubectl delete "ingress/gke-ingress" --namespace "httpd-ing"
kubectl delete namespace "httpd-ing"