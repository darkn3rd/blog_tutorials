resource "random_pet" "prefix" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# resource "random_id" "log_analytics_workspace_name_suffix" {
#   byte_length = 8
# }
#
# resource "azurerm_log_analytics_workspace" "test" {
#   # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
#   name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
#   location            = var.log_analytics_workspace_location
#   resource_group_name = azurerm_resource_group.k8s.name
#   sku                 = var.log_analytics_workspace_sku
# }
#
# resource "azurerm_log_analytics_solution" "test" {
#   solution_name         = "ContainerInsights"
#   location              = azurerm_log_analytics_workspace.test.location
#   resource_group_name   = azurerm_resource_group.k8s.name
#   workspace_resource_id = azurerm_log_analytics_workspace.test.id
#   workspace_name        = azurerm_log_analytics_workspace.test.name
#
#   plan {
#     publisher = "Microsoft"
#     product   = "OMSGallery/ContainerInsights"
#   }
# }

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  default_node_pool {
    name       = "agentpool"
    node_count = var.agent_count
    vm_size    = var.vm_size
  }

  # service_principal {
  #   client_id     = var.client_id
  #   client_secret = var.client_secret
  # }

  identity {
    type = "SystemAssigned"
  }

  # addon_profile {
  #   oms_agent {
  #     enabled                    = true
  #     log_analytics_workspace_id = azurerm_log_analytics_workspace.test.id
  #   }
  # }

  network_profile {
    load_balancer_sku = "Standard"
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
  }

  tags = {
    Environment = "Development"
  }
}
