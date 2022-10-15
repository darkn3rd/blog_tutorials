#!/usr/bin/env bash
export PROJECT_DIR=~/projects/consul_connect

mkdir -p $PROJECT_DIR/{examples/dgraph,consul}
cd $PROJECT_DIR
touch {consul,examples/dgraph}/helmfile.yaml \
 examples/dgraph/dgraph_allow_list.sh
