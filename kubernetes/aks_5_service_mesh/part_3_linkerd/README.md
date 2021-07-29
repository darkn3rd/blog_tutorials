# AKS with Linkerd Service Mesh

This tutorial covers using Linkerd servcie mesh.

This is the source code for this article:

* [Linkerd Service Mesh on AKS](https://joachim8675309.medium.com/linkerd-service-mesh-on-aks-a75d60ef4f5a)

# Instructions

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

# default linkerd registry/org
export LINKERD_REGISTRY="cr.l5d.io/linkerd"

# only used with helm chart (skip if not using helm chart)
LINKERD_EXP=$(date -v+8760H +"%Y-%m-%dT%H:%M:%SZ" 2> /dev/null) || \
 LINKERD_EXP=$(date -d '+8760 hour' +"%Y-%m-%dT%H:%M:%SZ")
export LINKERD_EXP
EOF
```

## Provision AKS Cluster

```bash
source env.sh
bash scripts/create_aks_with_acr.sh
```

You can view the components with:

```bash
source env.sh
kubectl get all --all-namespaces
```

To view the IP addresses of the nodes, run:

```bash
JSONPATH='{range .items[*]}{@.metadata.name}{"\t"}{@.status.addresses[?(@.type == "InternalIP")].address}{"\n"}{end}'
kubectl get nodes --output jsonpath="$JSONPATH"
```

## Republish Linkerd Images

If you wish to republish images to ACR, you can following these instructions:

* [part_0_docker/linkerd/README.md](../part_0_docker/linkerd/README.md)

After you need to update the `LINKERD_REGISTRY` value to point to ACR:

```bash
echo 'export LINKERD_REGISTRY="${AZ_ACR_LOGIN_SERVER}/linkerd"' >> env.sh
```

## Install Linkerd

```bash
source env.sh
bash scripts/create_certs.sh
bash scripts/deploy_linkerd.sh
```

### Verify Linkerd

```bash
kubectl get all --namespace "linkerd"
linkerd check
```

## Liknerd Extensions

### Viz Dashboard

```bash
linkerd viz install | kubectl apply -f -
kubectl get all --namespace "linkerd-viz"
linkerd viz check
```

### Jaeger

```bash
linkerd jaeger install | kubectl apply -f -
kubectl get all --namespace "linkerd-jaeger"
linkerd jaeger check
```

## Dgraph

### Deploy Dgraph

```bash
source env.sh
bash examples/dgraph/deploy_dgraph.sh
```

### Pydgraph

You can deploy pydgraph-client with or without the proxy injection.  You can always add it later afterward.

#### Deploy pydgraph-client with proxy-injection

```bash
source env.sh
bash examples/dgraph/deploy_pydgraph.sh
```

#### Deploy pydgraph-client without proxy-injection (vanilla)

```bash
source env.sh
helmfile --file examples/pydgraph/helmfile.yaml apply
```

#### Add proxy-inject to existing deplohyed proxy injection

If the pydgraph-client was deployed without proxy-injection, you can add it later with the following command:

```bash
source env.sh
kubectl get --namespace pydgraph-client deploy --output yaml \
  | linkerd inject - \
  | kubectl apply --filename -
```

### Service Profile

You can create a service profile that is useful in load balacing gRPC traffic on Dgraph.

```bash
source env.sh
pushd examples/dgraph/
curl -sOL https://raw.githubusercontent.com/dgraph-io/dgo/v210.03.0/protos/api.proto
linkerd profile --proto pb.proto --namespace dgraph dgraph-svc | \
  kubectl apply --namespace "dgraph" --filename -
popd
```

### Network Policy for Linkerd

There's a network policy to restrict traffic to Dgraph for clients that are apart of service mesh:

```bash
source env.sh
kubectl apply --filename examples/dgraph/network_policy.yaml
```

After this is applied, any services that do not have the labels to show they are apart of the service mesh.  This can be further restricted by selecting pod labels that match pygraph-client for example.

# Cleanup

```bash
helm template "demo" dgraph/dgraph | kubectl delete --namespace "dgraph" --filename -
kubectl delete pvc --namespace "dgraph" --selector release="demo"
```
