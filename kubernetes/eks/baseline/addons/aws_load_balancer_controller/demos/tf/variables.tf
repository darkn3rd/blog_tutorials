variable "eks_cluster_name" {
  description = "Name of the target EKS cluster (must already have the aws-load-balancer-controller installed)"
  type        = string
}

variable "eks_region" {
  description = "AWS region where the EKS cluster runs"
  type        = string
}

variable "svc_nlb_namespace" {
  description = "Namespace for the Service/NLB demo. Created automatically unless it's \"default\"."
  type        = string
  default     = "default"
}

variable "ing_alb_namespace" {
  description = "Namespace for the Ingress/ALB demo. Created automatically unless it's \"default\"."
  type        = string
  default     = "default"
}

variable "gw_nlb_namespace" {
  description = "Namespace for the Gateway+TCPRoute/NLB demo. Created automatically unless it's \"default\"."
  type        = string
  default     = "default"
}

variable "gw_alb_namespace" {
  description = "Namespace for the Gateway+HTTPRoute/ALB demo. Created automatically unless it's \"default\"."
  type        = string
  default     = "default"
}
