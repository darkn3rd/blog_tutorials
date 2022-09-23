#!/usr/bin/env bash

source ./scripts/env.sh
./scripts/gke.sh

helmfile --file ./consul/helmfile.yaml apply

kubectl get namespace "dgraph" > /dev/null 2> /dev/null \
 || kubectl create namespace "dgraph" \
 && kubectl label namespace "dgraph" name=dgraph \
 && kubectl label namespace "dgraph" connect-inject=enabled

helmfile --file ./dgraph/helmfile.yaml apply



# CLEAN
helmfile --file ./dgraph/helmfile.yaml delete
kubectl delete pvc --selector app=dgraph --namespace "dgraph"
kubectl delete svc,sts,cm --selector app=dgraph --namespace "dgraph"

helmfile --file ./consul/helmfile.yaml delete
kubectl delete pvc --selector app=consul --namespace "consul"
