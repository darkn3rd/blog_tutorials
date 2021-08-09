#!/usr/bin/env bash

## Verify essential commands
command -v step > /dev/null || \
  { echo "[ERROR]: 'step' command not not found" 1>&2; exit 1; }

CERT_PATH=${CERT_PATH:-"$(dirname $0)/../certs"}

step certificate create root.linkerd.cluster.local \
  $CERT_PATH/ca.crt $CERT_PATH/ca.key \
  --profile root-ca --no-password --insecure

step certificate create identity.linkerd.cluster.local \
  $CERT_PATH/issuer.crt $CERT_PATH/issuer.key \
  --profile intermediate-ca --not-after 8760h \
  --no-password --insecure \
  --ca $CERT_PATH/ca.crt --ca-key $CERT_PATH/ca.key
