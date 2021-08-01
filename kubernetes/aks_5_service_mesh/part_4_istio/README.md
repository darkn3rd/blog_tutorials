# AKS with Istio Service Mesh

## Requirements

* [docker](https://docs.docker.com/get-docker/) - build/push images to ACR
* [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
* [helm](https://helm.sh/docs/intro/install/), [helm-diff](https://github.com/databus23/helm-diff), [helmfile](https://github.com/roboll/helmfile)
* [istioctl](https://istio.io/latest/docs/setup/install/istioctl/)

## Environment

```bash
cat <<-EOF > env.sh
# resource group
export AZ_RESOURCE_GROUP=netpolmesh-test
export AZ_LOCATION=westus2

# container registry
export AZ_ACR_NAME=netpolmeshtest
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)

# kubernetes cluster
export AZ_CLUSTER_NAME=netpolmesh-test
export AZ_NET_PLUGIN="azure"
export AZ_NET_POLICY="calico"
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml
EOF
```

### Istio CLI

#### macOS

```bash
brew install istioctl
```

## Kubernetes

### Deploy Istio

```bash
istioctl install --set profile=demo -y
```

### Deploy Telemetry Addons

```bash
# Fetch Files
VER="1.10"
PREFIX="raw.githubusercontent.com/istio/istio/release-${VER}/samples/addons/"
MANIFESTS=("grafana" "jaeger" "kiali" "prometheus" "prometheus_vm" "prometheus_vm_tls")
for MANIFEST in ${MANIFESTS[*]}; do
  curl --silent --location "https://$PREFIX/$MANIFEST.yaml" --output ./addons/$MANIFEST.yaml
done

kubectl apply -f ./addons
```

### See Dashboard

```bash
istioctl dashboard kiali
```

### Deploy Dgraph graph database

Deploy dgraph services along with network policy to block pods from namespaces that are not configured to use Istio service mesh.

See [examples/dgraph/README.md](examples/dgraph/README.md)

### Deploy Pydgraph graph database

This will deploy two clients: `pydgraph-allow` (has istio) and `pydgraph-deny`.

See [examples/pydgraph/README.md](examples/pydgraph/README.md)

## The Tests

### Baseline

Both HTTP and gRPC traffic should work from pods in both `pydgraph-deny` (no-proxy) and `pydgraph-deny` (envoy-proxy sidecar) namespaces.

### Test 1: Test Network Policy Denies Traffic

Both HTTP and gRPC will time out from pods in the `pydgraph-deny` (no-proxy) namespace.

### Test 2: Test Service Mesh

Both HTTP and gRPC will work from pods in the `pydgraph-allow` (no-proxy) namespace.

# TODOs

* add version tag for blue/green
