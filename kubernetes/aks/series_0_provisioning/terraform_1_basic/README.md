

# Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [Terraform](https://www.terraform.io/)

## Azure Subscription

An account needs to be registered to create an Azure subscripiton, and then after installing `az`, run:

```bash
az login
```


# Steps

## Create Service Principal

```bash
export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')
az ad sp create-for-rbac \
  --name "${AZ_SP_NAME:-"aks-basic-test"}"
  --role="Contributor"
  --scopes="/subscriptions/$AZ_SUBSCRIPTION_ID" > secrets.json

TF_VAR_client_secret=$(jq -r .password secrets.json)
TF_VAR_client_id=$(jq -r .appId secrets.json)
```

## Create tf vars defaults

```bash
cat <<-EOF >> $TF_VARS
resource_group_name = "aks-basic-test"
location            = "westus2"
cluster_name        = "basic-test"
dns_prefix          = "basic-test"
EOF
```

# Links


* [Creating a Kubernetes Cluster with AKS and Terraform](https://www.hashicorp.com/blog/kubernetes-cluster-with-aks-and-terraform) on May 23 2018 by Nic Jackson - this article has not been updated and example code is Terraform v0.11 or earlier.

* [Provision an AKS Cluster (Azure)](https://learn.hashicorp.com/tutorials/terraform/aks)
  * Source Code: https://github.com/hashicorp/learn-terraform-provision-aks-cluster
* [Getting started with Terraform and Kubernetes on Azure AKS](https://learnk8s.io/terraform-aks)
* [Create a Kubernetes cluster with Azure Kubernetes Service using Terraform](https://docs.microsoft.com/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks) on Aug 07, 2021 - this article covers using Azure storage for maintaining state, and using Container Insights as well as basic Azure.
