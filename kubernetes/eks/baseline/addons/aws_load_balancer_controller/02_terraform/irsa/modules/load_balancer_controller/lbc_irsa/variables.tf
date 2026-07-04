variable "eks_cluster_name" {
  description = "Name of the target EKS cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the target EKS cluster, used to look up the IAM OIDC provider and build the IRSA trust policy"
  type        = string
}
