#!/usr/bin/env bash
export PROJECT_DIR=~/projects/linkerd

mkdir -p $PROJECT_DIR/{examples/dgraph,linkerd}
cd $PROJECT_DIR
touch {linkerd,examples/dgraph}/helmfile.yaml \
 examples/dgraph/dgraph_allow_list.sh
