#!/usr/bin/env bash
mkdir -p ~/azure_calico/examples/{dgraph,pydgraph} && cd ~/azure_calico

touch env.sh \
 ./examples/dgraph/{helmfile.yaml,network_policy.yaml} \
 ./examples/pydgraph/{Dockerfile,Makefile,helmfile.yaml,requirements.txt,load_data.py,sw.schema,sw.nquads.rdf}
