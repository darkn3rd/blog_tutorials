variable "resource_group_name" {
  description = "The resource group name to be imported"
  type        = string
}

variable "dns_prefix" {
  description = "The prefix for the resources created in the specified Azure Resource Group"
  type        = string
}

variable "name" {
  description = "The name for the AKS resources created in the specified Azure Resource Group."
  type        = string
  default     = null

}

variable "kubernetes_version" {
  description = "Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region"
  type        = string
  default     = null
}

variable "network_plugin" {
  description = "Network plugin to use for networking."
  type        = string
  default     = "kubenet"
}

variable "network_policy" {
  description = "Sets up network policy to be used with Azure CNI. Network policy allows us to control the traffic flow between pods. Currently supported values are calico and azure. Changing this forces a new resource to be created."
  type        = string
  default     = null
}

variable "admin_username" {
  default     = "azureuser"
  description = "The username of the local administrator to be created on the Kubernetes cluster"
  type        = string
}

variable "vm_size" {
  default     = "Standard_D2_v2"
  description = "The default virtual machine size for the Kubernetes agents"
  type        = string
}

variable "agent_count" {
  description = "The number of Agents that should exist in the Agent Pool."
  type        = number
  default     = 3
}

variable "ssh_public_key" {
  description = "A custom ssh key to control access to the AKS cluster"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
