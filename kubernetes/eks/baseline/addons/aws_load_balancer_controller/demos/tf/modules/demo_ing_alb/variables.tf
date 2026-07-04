variable "namespace" {
  description = "Namespace to deploy the demo into. Created automatically unless it's \"default\" (which always exists)."
  type        = string
  default     = "default"
}

variable "app_name" {
  description = "Name shared by the Deployment, Service, and Ingress"
  type        = string
  default     = "demo-alb-app"
}

variable "image" {
  description = "Container image for the demo app"
  type        = string
  default     = "nginx:alpine"
}

variable "hostname" {
  description = "Host used for ALB host-based routing"
  type        = string
  default     = "demo.example.com"
}
