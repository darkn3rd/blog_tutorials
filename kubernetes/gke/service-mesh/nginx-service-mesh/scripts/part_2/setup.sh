#!/usr/bin/env bash

# .
# ├── clients
# │   └── fetch_scripts.sh
# ├── dgraph
# │   ├── dgraph_allow_lists.sh
# │   ├── helmfile.yaml
# │   └── vs.yaml
# ├── kube_addons
# │   ├── cert_manager
# │   │   ├── helmfile.yaml
# │   │   └── issuers.yaml
# │   ├── external_dns
# │   │   └── helmfile.yaml
# │   └── nginx_ic
# │       ├── docker_keys.sh
# │       └── helmfile.yaml
# ├── nsm
# │   └── helmfile.yaml
# ├── o11y
# │   └── fetch_manifests.sh
# └── ratel
#     ├── helmfile.yaml
#     └── vs.yaml

PROJECT_DIR=~/projects/nsm

mkdir -p $PROJECT_DIR/{kube_addons/{cert_manager,external_dns,nginx_ic},ratel}
cd $PROJECT_DIR

touch {kube_addons/{nginx_ic,cert_manager,external_dns},ratel}/helmfile.yaml \
 kube_addons/cert_manager/issuers.yaml \
 kube_addons/nginx_ic/docker_keys.sh \
 {ratel,dgraph}/vs.yaml
