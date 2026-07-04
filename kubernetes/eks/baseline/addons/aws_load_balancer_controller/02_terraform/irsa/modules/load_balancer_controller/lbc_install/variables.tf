variable "eks_cluster_name" {
  description = "Name of the target EKS cluster"
  type        = string
}

variable "eks_region" {
  description = "AWS region where the EKS cluster runs"
  type        = string
}

variable "chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart to install"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID of the target EKS cluster"
  type        = string
}

variable "role_arn" {
  description = "ARN of the IAM role to annotate onto the controller's service account (from the lbc_irsa module)"
  type        = string
}

variable "use_experimental_gateway_api" {
  description = "Install the Gateway API experimental channel CRDs instead of the standard channel. Only one channel may be installed at a time."
  type        = bool
  default     = true
}
