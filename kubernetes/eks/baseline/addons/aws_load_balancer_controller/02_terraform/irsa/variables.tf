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