#!/usr/bin/env bash

## Verify essential commands
command -v linkerd > /dev/null || \
  { echo "[ERROR]: 'linkerd' command not not found" 1>&2; exit 1; }

# NOTE: namespace is embedded
linkerd jaeger install | kubectl apply -f -
