# Telemetry Addons

```bash
VER="1.10"
PREFIX="raw.githubusercontent.com/istio/istio/release-${VER}/samples/addons/"
MANIFESTS=("grafana" "jaeger" "kiali" "prometheus" "prometheus_vm" "prometheus_vm_tls")
for MANIFEST in ${MANIFESTS[*]}; do
  curl --silent --location "https://$PREFIX/$MANIFEST.yaml" --output ./$MANIFEST.yaml
done
```
