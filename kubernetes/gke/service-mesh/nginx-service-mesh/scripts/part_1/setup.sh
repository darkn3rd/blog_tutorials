#!/usr/bin/env bash

# ~/projects/nsm
# ├── clients
# │   └── fetch_scripts.sh
# ├── dgraph
# │   ├── dgraph_allow_lists.sh
# │   └── helmfile.yaml
# ├── nsm
# │   └── helmfile.yaml
# └── o11y
#     └── fetch_manifests.sh


PROJECT_DIR=~/projects/nsm
mkdir -p $PROJECT_DIR/{clients,dgraph,nsm,o11y}
cd $PROJECT_DIR

touch {nsm,dgraph}/helmfile.yaml \
 o11y/fetch_manifests.sh \
 dgraph/dgraph_allow_lists.sh \
 clients/fetch_scripts.sh
