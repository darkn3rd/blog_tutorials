# AKS with Istio Service Mesh

## Published Blogs

* https://joachim8675309.medium.com/istio-service-mesh-on-aks-1b6ed16f6890

## Requirements

* [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
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
MANIFESTS=(grafana jaeger kiali prometheus{,_vm,_vm_tls})

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


# Cleanup

To delete all Azure cloud resources, including cloud resources allocated from Kubernetes resoruces, such as persistent volumes.

```bash
az aks delete --resource-group ${AZ_RESOURCE_GROUP} --name ${AZ_CLUSTER_NAME}
az acr delete --resource-group ${AZ_RESOURCE_GROUP} --name ${AZ_ACR_NAME}
```

## Cleanup Dgraph

When using a non-AKS Kubernetes cluster, or if you only want to delete existing resources, you can delete Dgraph along with persistent volumes.

```bash
helm delete "demo" --namespace "dgraph"
kubectl delete pvc --namespace "dgraph" --selector release="demo"
```

# Links

## JsonPath Template Language

* https://kubernetes.io/docs/reference/kubectl/jsonpath/
* https://jsonpath.com/
  * https://github.com/ashphy/jsonpath-online-evaluator
* https://goessner.net/articles/JsonPath/
* https://pkg.go.dev/k8s.io/client-go/util/jsonpath

## Integrations

* ExternalDNS
  * [Configuring ExternalDNS to use the Istio Gateway and/or Istio Virtual Service Source](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/istio.md), Accessed 2 Aug 2021.
* CertManager
  * [cert-manager](https://istio.io/latest/docs/ops/integrations/certmanager/), Istio Documentation, Accessed 2 Aug 2021.

## AKS Documentaiton

* [Install and use Istio in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/servicemesh-istio-install?pivots=client-operating-system-linux), Azure Documentation, 2 Oct 2019.
* [Azure](https://istio.io/latest/docs/setup/platform-setup/azure/), Istio Documentation,12 Sep 2019.

## Istio Documention

* [Getting Started](https://istio.io/latest/docs/setup/getting-started/), Istio Documention, Accessed 1 Aug 2021.
* [Request Routing](https://istio.io/latest/docs/tasks/traffic-management/request-routing/), Istio Documentation, Accessed 1 Aug 2021.
* [Gateway](https://istio.io/latest/docs/reference/config/networking/gateway/), Istio Documentation, Accessed 2 Aug 2021.
* [VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/), Istio Documentation, Accessed 2 Aug 2021.
* [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/), Istio Documentation, Accessed 2 Aug 2021.


## Microservice Example Applications

These are applications that have multiple moving parts that can be useful in testing example applications.

* https://github.com/istio/istio/tree/master/samples/bookinfo
* https://github.com/spikecurtis/yaobank
* https://github.com/BuoyantIO/emojivoto
* https://github.com/BuoyantIO/booksapp
* https://github.com/argoproj/argocd-example-apps/tree/master/helm-guestbook
* https://github.com/dockersamples/example-voting-app
* https://github.com/GoogleCloudPlatform/istio-samples/tree/master/sample-apps/grpc-greeter-go
* https://github.com/GoogleCloudPlatform/istio-samples/tree/master/sample-apps/helloserver

The application used in this example is Dgraph, which is a distributed graph database with a web interface: gRPC (HTTP/2) and HTTP with both REST and GraphQL interfaces.


* Dgraph Server: https://github.com/dgraph-io/dgraph
* Python Client: https://github.com/dgraph-io/pydgraph
