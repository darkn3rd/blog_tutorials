# Baisc Cluster

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
    * VMSS with 3 worker nodes
    * Managed Identity for the worker nodes
      * DNS contributor role added
    * Virtual Network
    * Routes
      * route to pod overlay networks on the Nodes

* https://joachim8675309.medium.com/azure-kubernetes-service-b89cc52b7f02

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes

## Instructions

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=dgraph-test
export AZ_CLUSTER_NAME=dgraph-test
export AZ_LOCATION=westus2
export AZ_DNS_DOMAIN="example.internal"
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME
EOF

source env.sh

./create_cluster.sh
./cerate_dns.sh

# allow access to DNS zone from AKS nodes
./attach_dns.sh
```
