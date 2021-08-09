# AKS with Azure CNI and Calico Network Policies

This tutorial covers using Calico for Kubernetes network policies.

## Published Blogs

* https://joachim8675309.medium.com/aks-with-calico-network-policies-8cdfa996e6bb

# Instructions

## Create env.sh file

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

## Create an container registry

The container registry should have been created in a previous step. See [part_0_docker/README.md](../part_0_docker/README.md)

You can use the script below to create the ACR:

```bash
source env.sh
bash scripts/create_acr.sh
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

## Deploy Dgraph database

See [examples/dgraph/README.md](examples/dgraph/README.md)

## Build and push an pydgraph image

See [../part_0_docker/pydgraph/README.md](part_0_docker/pydgraph/README.md)

## Deploy pydgraph container

See [examples/pydgraph/README.md](examples/pydgraph/README.md)

## Using Network Policy

When applied, all traffic outside of the dgraph namespace will be blocked. Only pods running in a namespace with the label of `app=dgraph-client` will be able to access Dgraph servcies on port `8080` and port `9080`

```bash
kubectl --filename exapmles/dgraph/networkpolicy.yaml apply
```
As an example, to allow the pydrgraph-client to access Dgraph, run this:

```bash
kubectl label namespaces "pydgraph-client" env=test app=dgraph-client
```

# Cleanup

```bash
source env.sh
bash scripts/delete_aks.sh.sh
rm -rf ${KUBECONFIG}
```

# Links, References, and other Resources

* [Guide to Kubernetes Ingress Network Policies](https://www.openshift.com/blog/guide-to-kubernetes-ingress-network-policies)
  * [Examples from the Network Policies guide](https://github.com/stackrox/network-policy-examples)
* [Securing Kubernetes Cluster Networking](https://ahmet.im/blog/kubernetes-network-policy/) by Ahmet Alp Balkan
* [Get started with Kubernetes network policy](https://docs.projectcalico.org/security/kubernetes-network-policy)
