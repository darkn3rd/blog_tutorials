#!/usr/bin/env bash
source env.sh

# Ratel Resources
kubectl delete deploy/dgraph-ratel --namespace "ratel"
kubectl delete svc/dgraph-ratel --namespace "ratel"

# VirtualServers
helm delete dgraph-virtualservers --namespace "dgraph"
helm delete ratel-virtualserver --namespace "ratel"

# Kubernetes Addons
helm delete "external-dns" --namespace "kube-addons"
helm delete "nginx-ingress" --namespace "kube-addons"
helm delete "cert-manager-issuers" --namespace "kube-addons"
helm delete "cert-manager" --namespace "kube-addons"
