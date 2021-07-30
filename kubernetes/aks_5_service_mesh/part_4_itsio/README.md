# AKS with Itsio Service Mesh


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

### Itsio CLI

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
