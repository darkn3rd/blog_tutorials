#!/usr/bin/env bash
source env.sh

# delete pydgraph-client
helmfile --file ./examples/dgraph/helmfile.yaml delete
kubectl delete namespace pydgraph-client

# delete dgraph
helmfile --file ./examples/dgraph/helmfile.yaml delete
kubectl delete pvc --selector app=dgraph --namespace "dgraph"
kubectl delete namespace dgraph

# delete consul
helmfile --file ./consul/helmfile.yaml delete
kubectl delete pvc --selector app=consul --namespace "consul"
kubectl delete namespace consul
