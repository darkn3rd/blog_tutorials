terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
  }
}
