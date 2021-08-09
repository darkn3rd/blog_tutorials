#!/usr/bin/env bash
mkdir -p ~/azure_ingress_nginx/examples/{dgraph,hello} && cd ~/azure_ingress_nginx
touch env.sh helmfile.yaml examples/{dgraph,hello}/helmfile.yaml
