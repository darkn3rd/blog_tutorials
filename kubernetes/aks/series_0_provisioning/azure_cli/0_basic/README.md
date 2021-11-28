# Basic Cluster

This is a basic HA cluster with three nodes, one node per zone.

This cluster will have the following details:

* AKS (Kubernetes)
  * Kubernetes version: latest per region (v1.20.7 for `westus2` on 2021-Aug-21)
  * Network Plugin: `kubenet`
  * Network Policy: none
  * Max Pods for Cluster: 250
    * Max Pods per Node: 110
  * Azure Resoruces:
    * Load Balancer (Standard)
    * Public IP
    * Network Security Group
    * VMSS with 3 worker nodes (1 node per zone)
      * Managed Identity for the worker nodes
    * Virtual Network
    * Routes
      * route to pod overlay networks on the Nodes

## Blogs Using this Content

* https://joachim8675309.medium.com/azure-kubernetes-service-b89cc52b7f02

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes

## Instructions

### Create Environment Configuration

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=blog-test
export AZ_AKS_CLUSTER_NAME=blog-test
export AZ_LOCATION=westus2
EOF
```

### Create Cluster

```bash
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}
../scripts/create_cluster.sh
```

## Verifiication

### Verify Kubernetes Cluster

Verify your access to the cluster using `kubectl`

```bash
source env.sh
kubectl get all --all-namespaces
```
