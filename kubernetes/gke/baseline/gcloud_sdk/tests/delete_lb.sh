#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

## Cleanup
kubectl delete "service/httpd" --namespace "httpd-svc"
kubectl delete namespace "httpd-svc"