#!/usr/bin/env bash
mkdir -p ~/azure_ingress_nginx_grpc/examples/{dgraph,hello} && cd ~/azure_cert_manager
touch env.sh helmfile.yaml ./examples/{dgraph,hello}/helmfile.yaml
