
## Prerequisites

* GKE Cluster

## Installation

Installation using the Helm chart is the preferred way, as Helm is more ubiquitous and transparent.  It allows you to learn the Linkerd components, but also integration with other platforms, such as Prometheus.  The linkerd cli tool is easier to use, especially as it comes with canned defaults useful in getting started.


1. Generate root CA certificate.  See [README.md](certs/README.md)
2. Install Control Plane


as you can track and see all of the components installed, as well as use tooling that is more ubiquitous. 

### Helm Chart (preferred)

Helm chart is the preferred way, as you can track and see all of the components installed, as well as use tooling that is more ubiquitous. 



```bash
helm repo add linkerd https://helm.linkerd.io/stable && helm repo update

helm install linkerd-crds linkerd/linkerd-crds \
  -n linkerd --create-namespace

helm fetch --untar linkerd/linkerd-control-plane

helm install linkerd-control-plane \
  --namespace linkerd \
  --set-file identityTrustAnchorsPEM=./certs/ca.crt \
  --set-file identity.issuer.tls.crtPEM=./certs/issuer.crt \
  --set-file identity.issuer.tls.keyPEM=./certs/issuer.key \
  --values linkerd-control-plane/values-ha.yaml \
  linkerd/linkerd-control-plane
```

## Monitoring

```
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana -n grafana --create-namespace grafana/grafana \
  -f https://raw.githubusercontent.com/linkerd/linkerd2/main/grafana/values.yaml
```

## Installation with Linkerd CLI

```bash
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
```

### Extensions

```bash
linkerd viz install | kubectl apply -f -
linkerd jaeger install | kubectl apply -f -
```