# Provisioning AKS

This area covers topics on standing up an AKS cluster.

* Azure CLI
  * [Basic](./azure_cli/0_basic/README.md) - provision cluster with `az` using the default network plugin `kubenet`.
* Terraform
  * [Basic](./terraform/0_basic/README.md) - provision cluster with `terraform` using the default network plugin `kubenet`.
  * [Calico](./terraform/0_basic/README.md) - provision cluster with `terraform` using the network plugin `azure` and network policies with `calico`.