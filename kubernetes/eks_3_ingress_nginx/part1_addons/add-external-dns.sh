#!/usr/bin/env bash
command -v kubectl > /dev/null || \
  { echo 'kubectl command not not found' 1>&2; exit 1; }
command -v helm > /dev/null || \
  { echo 'helm command not not found' 1>&2; exit 1; }

## required settings
[[ -z "$MY_DOMAIN" ]] && { echo 'MY_DOMAIN not specified. Aborting' 2>&1 ; return 1; }

## namespace
NAMESPACE=${MY_NAMESPACE:="kube-addons"}

## create values config from template
sed -e "s/\$MY_CLUSTER_NAME/$MY_DOMAIN/" \
    template.external-dns.yaml> values.external-dns.yaml

## add helm repository
helm repo add "bitnami" "https://charts.bitnami.com/bitnami"
helm repo update

## idempotent create namespace
if ! kubectl get namespace | grep -q $NAMESPACE; then
  kubectl create namespace $NAMESPACE
fi

## install helm chart
helm install externaldns --namespace $NAMESPACE --values values.external-dns.yaml bitnami/external-dns
