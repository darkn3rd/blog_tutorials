#!/usr/bin/env bash
mkdir -p ~/azure_itsio/{addons,examples/{dgraph,pydgraph}} && cd ~/azure_itsio
touch env.sh \
  ./examples/dgraph/{helmfile.yaml,network_policy.yaml} \
  ./examples/pydgraph/{Dockerfile,Makefile,helmfile.yaml,requirements.txt,load_data.py,sw.schema,sw.nquads.rdf} \
  ./addons/{grafana,jaeger,kiali,prometheus{,_vm,_vm_tls}}.yaml \
