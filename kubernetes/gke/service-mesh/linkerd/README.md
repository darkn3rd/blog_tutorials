# Linkerd Service Mesh

## Prerequisites

* [Step CLI](https://smallstep.com/docs/step-cli/installation)
* `kubectl`
* `helm`
* `helmfile`

## Creating Certificates with Step

```bash
pushd control_plane/certs
step certificate create root.linkerd.cluster.local ca.crt ca.key \
  --profile root-ca --no-password --insecure
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
  --profile intermediate-ca --not-after 8760h --no-password --insecure \
  --ca ca.crt --ca-key ca.key
popd
```

## Installation Using Helm Chart

For installation using the helm chart, you can use either `helm` tool, or `helmfile` tool.

### Installing Using Helm

```bash
pushd control_plane
helm repo add linkerd https://helm.linkerd.io/stable
helm install linkerd-control-plane -n linkerd \
  --set-file identityTrustAnchorsPEM=ca.crt \
  --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key \
  -f linkerd2/values-ha.yaml
  linkerd/linkerd-control-plane
popd
```

### Installing Using Helmfile

```bash
pushd control_plane
helmfile apply
popd
```


# References

* [Install step](https://smallstep.com/docs/step-cli/installation)
