#!/usr/bin/env bash

## Verify essential commands
command -v linkerd > /dev/null || \
  { echo "[ERROR]: 'linkerd' command not not found" 1>&2; exit 1; }
command -v kubectl > /dev/null || \
  { echo "[ERROR]: 'kubectl' command not not found" 1>&2; exit 1; }

CERT_PATH=${CERT_PATH:-"$(dirname $0)/../certs"}

# NOTE: namespace is embedded
linkerd install \
  --identity-trust-anchors-file $CERT_PATH/ca.crt \
  --identity-issuer-certificate-file $CERT_PATH/issuer.crt \
  --identity-issuer-key-file $CERT_PATH/issuer.key \
  | kubectl apply -f -
