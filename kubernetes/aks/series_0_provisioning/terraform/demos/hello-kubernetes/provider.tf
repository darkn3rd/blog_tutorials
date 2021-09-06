terraform {
  required_providers {

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

data "azurerm_kubernetes_cluster" "default" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
}

provider "azurerm" {
  features {}
}
