#!/usr/bin/env bash

# required command line tools
command -v helm > /dev/null || \
  { echo "[ERROR]: 'helm' command not not found" 1>&2; exit 1; }
command -v helmfile > /dev/null || \
  { echo "[ERROR]: 'helmfile' command not not found" 1>&2; exit 1; }
command -v kubectl > /dev/null || \
  { echo "[ERROR]: 'kubectl' command not not found" 1>&2; exit 1; }

# deploy pydgraph clients
HELMFILE=${HELMFILE:-"$(dirname $0)/helmfile.yaml"}
helmfile --file $HELMFILE apply
