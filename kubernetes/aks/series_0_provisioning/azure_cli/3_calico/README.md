# AKS with Calico for network policies

This creates an a basic HA cluster with network plugins Azure CNI and Calico.  

In this scenario, both pods and nodes are on the same virtual network due to Azure CNI.  Anything deployed on the virtual network will be able to connect to pods without out going through an loadbalancer endpoint created through a `service` (type `LoadBalancer`) or an `ingress`.

This understandably is dangerous, so `network policies` is enabled through the Calico network plugin that will *allow* you to add further security.  You can create a policy that will DENY all ingress traffic to the pods, while configuring ALLOW traffic from pods or external traffic depending on a set of requirements you specify.

This cluster will have the following details:

* AKS (Kubernetes)
  * Kubernetes version: latest per region (v1.20.7 for `westus2` on 2021-Aug-21)
  * Network Plugin: `azure`
  * Network Policy: `calico`
  * Max Pods for Cluster: 250
    * Max Pods per Node: 110
  * Azure Resoruces:
    * Load Balancer (Standard)
    * Public IP
    * Network Security Group
    * VMSS with 3 worker nodes
    * Managed Identity for the worker nodes
      * AcrPull role added
    * Virtual Network
    * Routes
      * route to pod overlay networks on the Nodes

## Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes

## Instructions

```bash
# create environment source file
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=blog-test
export AZ_CLUSTER_NAME=blog-test
export AZ_LOCATION=westus2
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME.yaml

export AZ_NET_PLUGIN="azure"
export AZ_NET_POLICY="calico"
EOF

source env.sh

../scripts/create_cluster.sh
```

## Verifiication

### Verify Kubernetes Cluster

Verify your access to the cluster using `kubectl`

```bash
source env.sh
kubectl get all --all-namespaces
```

You should see several new pods for Calico.

## Cleanup

```bash
source env.sh
../scripts/delete_cluster.sh
```

## Resources

* [Configure Azure CNI networking in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni)
* [Secure traffic between pods using network policies in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/use-network-policies)
