#!/usr/bin/env bash

# Kubernetes Resources - dgraph
helm delete "external-dns" --namespace "kube-addons"
helm delete "cert-manager-issuers" --namespace "kube-addons"
helm delete "cert-manager" --namespace "kube-addons"
helm delete "nginx-ingress" --namespace "kube-addons"

../scripts_1/clean_k8s.sh
