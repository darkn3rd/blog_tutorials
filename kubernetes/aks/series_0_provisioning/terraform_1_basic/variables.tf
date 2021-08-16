variable "resource_group_name" {}
variable "location" {}

variable "client_id" {}
variable "client_secret" {}


variable "dns_prefix" {}
variable "cluster_name" {}

variable "network_plugin" { default = "kubenet" }
variable "network_policy" { default = "" }
variable "vm_size" { default = "Standard_D2_v2" }
variable "agent_count" { default = 3 }
variable "ssh_public_key" { default = "~/.ssh/id_rsa.pub" }


variable "log_analytics_workspace_name" { default = "testLogAnalyticsWorkspaceName" }
# refer https://azure.microsoft.com/global-infrastructure/services/?products=monitor for log analytics available regions
variable "log_analytics_workspace_location" { default = "eastus" }
# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing
variable "log_analytics_workspace_sku" { default = "PerGB2018" }
