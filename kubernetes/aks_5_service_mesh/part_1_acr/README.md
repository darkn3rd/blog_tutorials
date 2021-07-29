# AKS with ACR registry integration

This tutorial covers using a private container registry with your Kubernetes deployments.

This is the source code for this article:

* [AKS with Azure Container Registry](https://joachim8675309.medium.com/aks-with-azure-container-registry-b7ff8a45a8a)

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
export AZ_LOCATION=westus2
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml
EOF
```

## Create an container registry

The container registry should have been created in a previous step. See [part_0_docker/README.md](../part_0_docker/README.md) for further information.

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

## Deploy Dgraph database

See [examples/dgraph/README.md](examples/dgraph/README.md)

## Build and push an pydgraph image

See [part_0_docker/pydgraph/README.md](../part_0_docker/pydgraph/README.md)

## Deploy pydgraph container

See [examples/pydgraph/README.md](examples/pydgraph/README.md)

# Cleanup

```bash
source env.sh
bash scripts/delete_aks.sh.sh
rm -rf ${KUBECONFIG}
```

# Links

* [Authenticate with Azure Container Registry from Azure Kubernetes Service](https://docs.microsoft.com/azure/aks/cluster-container-registry-integration)
* [Pull images from an Azure container registry to a Kubernetes cluster using a pull secret](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-kubernetes)
