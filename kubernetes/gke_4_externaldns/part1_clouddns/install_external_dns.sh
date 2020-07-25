#!/usr/bin/env bash

## Check for helm command
command -v helm > /dev/null || \
  { echo 'ERROR: helm command not not found' >&2; exit 1; }


## Check for arguments
(( $# < 1 )) && \
  { printf "   Usage: $0 <MY_DOMAIN> [release-name]\n\n" >&2; exit 1; }

## Variables
MY_DOMAIN=${1}
MY_RELEASE=${2:-"tutorial-externaldns"}

## Update or install bitnami helm charts
if helm repo list | grep -q https://charts.bitnami.com/bitnami; then
  helm repo update
else
  helm repo add bitnami https://charts.bitnami.com/bitnami
fi

## Test Helm with current KUBECONFIG context
MESSAGE=$(helm ls 2>&1)
if [[ $? -ne 0 ]]; then 
  printf "ERROR: Helm failed with this error: \n\t%s\n" "$MESSAGE" 
  exit 1
fi

## Create Values file from template
sed "s/\$MY_DOMAIN/$MY_DOMAIN/" template_values.yaml > gcp-external-dns.values.yaml

helm install $MY_RELEASE \
--values gcp-external-dns.values.yaml \
  bitnami/external-dns

