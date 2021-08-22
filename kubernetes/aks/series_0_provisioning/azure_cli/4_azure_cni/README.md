# AKS using Azure CNI network plugin with separate Pod VNET

This scenario will create a HA Kubernetes cluster with Pods placed on a separate network from the Nodes.  

With Azure CNI, pods are placed on Azure VNET that is used by the Nodes.  This introduces potential security issues as pods can be directly accessed by VMs on the same subnet, and issues where IP addresses can get exhausted when assigned to both pods and nodes.
