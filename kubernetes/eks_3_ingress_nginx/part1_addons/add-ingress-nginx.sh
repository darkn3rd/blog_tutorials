#!/usr/bin/env bash
command -v kubectl > /dev/null || \
  { echo 'kubectl command not not found' 1>&2; exit 1; }
command -v helm > /dev/null || \
  { echo 'helm command not not found' 1>&2; exit 1; }

## required settings
[[ -z "$MY_ACM_ARN" ]] && { echo 'MY_ACM_ARN not specified. Aborting' 2>&1 ; return 1; }

## namespace
NAMESPACE=${MY_NAMESPACE:="kube-addons"}

## create values config from template
sed -e "s/\$MY_CLUSTER_NAME/$MY_ACM_ARN/" \
    template.nginx-ingress.yaml > values.nginx-ingress.yaml

## add helm repository
helm repo add "ingress-nginx" "https://kubernetes.github.io/ingress-nginx"
helm repo update

## idempotent create namespace
if ! kubectl get namespace | grep -q $NAMESPACE; then
  kubectl create namespace $NAMESPACE
fi

## install helm chart
helm install ingress-nginx --namespace $NAMESPACE --values values.nginx-ingress.yaml ingress-nginx/ingress-nginx
