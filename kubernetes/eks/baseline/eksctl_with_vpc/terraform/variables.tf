variable "aws_profile" {
  type = string
}

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
