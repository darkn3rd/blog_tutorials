variable "eks_cluster_name" {
  type = string
}

variable "eks_region" {
  type = string
}

variable "eks_version" {
  type = string
}

variable "public_subnet_ids" {
  type = map(string)
}

variable "private_subnet_ids" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}
