variable "auth_mode" {
  description = "Which mechanism grants the controller's ServiceAccount IAM permissions: \"irsa\" or \"pod_identity\". Passed straight through to lbc_auth, which validates it."
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the target EKS cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the target EKS cluster. Required when auth_mode is \"irsa\"; ignored otherwise."
  type        = string
  default     = null
}

variable "role_name" {
  description = "Name of the IAM role to create for the controller's ServiceAccount. Defaults to \"$${eks_cluster_name}-aws-load-balancer-controller\" if not set. Passed straight through to lbc_auth."
  type        = string
  default     = null
}

variable "policy_name" {
  description = "Name of the IAM policy to create for the controller's ServiceAccount. Defaults to \"AWSLoadBalancerControllerIAMPolicy\" if not set. Passed straight through to lbc_auth."
  type        = string
  default     = null
}
