variable "eks_cluster_name" {
  type = string
}

variable "eks_region" {
  type    = string
  default = "us-east-2"
}

variable "eks_version" {
  type = string
}

variable "chart_version" {
  type    = string
  default = "3.4.0"
}

variable "role_name" {
  description = "Name of the IAM role to create for the controller's ServiceAccount. Defaults to \"$${eks_cluster_name}-aws-load-balancer-controller\" if not set."
  type        = string
  default     = null
}

variable "policy_name" {
  description = "Name of the IAM policy to create for the controller's ServiceAccount. Defaults to \"AWSLoadBalancerControllerIAMPolicy\" if not set."
  type        = string
  default     = null
}
