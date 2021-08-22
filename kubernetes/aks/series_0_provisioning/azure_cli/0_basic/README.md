# Baisc Cluster

This is a basic HA cluster with three nodes, one node per zone.

This cluster will have the following details:

* AKS (Kubernetes)
  * Version v1.20.7 (2021-Aug-21) - default is latest per region
  * Max Pods: 250
  * Max Pods per Node: 110 (`kubenet`)


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
EOF

export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME
```
