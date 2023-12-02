

1. Generate root CA certificate.  See [README.md](certs/README.md)
2. Install Control Plane

```bash
helm install linkerd-crds linkerd/linkerd-crds \
  -n linkerd --create-namespace

helm install linkerd-control-plane \
  --namespace linkerd \
  --set-file identityTrustAnchorsPEM=./certs/ca.crt \
  --set-file identity.issuer.tls.crtPEM=./certs/issuer.crt \
  --set-file identity.issuer.tls.keyPEM=./certs/issuer.key \
  --values linkerd-control-plane/values-ha.yaml \
  linkerd/linkerd-control-plane
```