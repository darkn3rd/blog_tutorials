#!/usr/bin/env sh
#############################
# helm.sh
# Description:
#  Install Linkerd using helm charts as per documentation:
#  * https://linkerd.io/2.12/tasks/install-helm/
#############################

command -v helm || { echo "Error: 'helm' command not found" 1>&2; exit 1; }

LINKERD_OPTIONS=""
[ "$LINKERD_HA" = "true" ] && LINKERD_OPTIONS=" --values ./config.yaml "


helm install linkerd-crds linkerd/linkerd-crds \
  --namespace linkerd --create-namespace

helm install linkerd-control-plane \
  --namespace linkerd \
  --set-file identityTrustAnchorsPEM=./certs/ca.crt \
  --set-file identity.issuer.tls.crtPEM=./certs/issuer.crt \
  --set-file identity.issuer.tls.keyPEM=./certs/issuer.key \
  $LINKERD_OPTIONS \
  linkerd/linkerd-control-plane
