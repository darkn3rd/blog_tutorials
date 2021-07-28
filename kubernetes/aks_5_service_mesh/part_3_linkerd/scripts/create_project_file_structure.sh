#!/usr/bin/env bash
mkdir -p ~/azure_linkerd/{certs,examples/{dgraph,pydgraph}} && cd ~/azure_linkerd

touch env.sh \
 ./certs/{ca,issuer}{.key,.crt} \
 ./examples/dgraph/{helmfile.yaml,network_policy.yaml} \
 ./examples/pydgraph/{Dockerfile,Makefile,helmfile.yaml,requirements.txt,load_data.py,sw.schema,sw.nquads.rdf}
