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

variable "sa_name" {
  description = "Name of the pre-created Kubernetes service account for the controller (from the lbc_prep module)"
  type        = string
}
