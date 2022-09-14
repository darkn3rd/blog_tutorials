#!/usr/bin/env bash
# .
# ├── clients
# │   └── fetch_scripts.sh
# ├── dgraph
# │   ├── dgraph_allow_lists.sh
# │   └── helmfile.yaml
# ├── kube-addons
# │   ├── helmfile.yaml
# │   └── issuers.yaml
# ├── nginx_ic
# │   ├── docker_keys.sh
# │   └── helmfile.yaml
# ├── nsm
# │   └── helmfile.yaml
# ├── o11y
# │   └── fetch_manifests.sh
# └── ratel
#     └── helmfile.yaml

PROJECT_DIR=~/projects/nsm
PROJECT_DIR=./projects/nsm

mkdir -p $PROJECT_DIR/{kube-addons,nginx_ic,ratel}
cd $PROJECT_DIR
touch {nginx_ic,kube-addons,ratel}/helmfile.yaml \
 kube-addons/issuers.yaml \
 nginx_ic/docker_keys.sh
