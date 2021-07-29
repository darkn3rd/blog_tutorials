#!/usr/bin/env bash
mkdir -p ~/azure_acr/examples/{dgraph} && cd ~/azure_acr
touch \
 env.sh \
 ./examples/{dgraph,pydgraph}/helmfile.yaml \
 ./examples/pydgraph/{Dockerfile,Makefile,requirements.txt,oad_data.py,sw.schema,sw.nquads.rdf}
