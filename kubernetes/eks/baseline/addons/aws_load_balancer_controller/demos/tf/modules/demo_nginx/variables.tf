variable "namespace" {
  description = "Namespace to deploy into. Created automatically unless it's \"default\" (which always exists)."
  type        = string
  default     = "default"
}

variable "app_name" {
  description = "Name shared by the Deployment and Service"
  type        = string
  default     = "demo-app"
}

variable "image" {
  description = "Container image for the demo app"
  type        = string
  default     = "nginx:alpine"
}

variable "service_type" {
  description = "Kubernetes Service type"
  type        = string
  default     = "ClusterIP"
}

variable "service_annotations" {
  description = "Annotations to add to the Service (e.g. AWS Load Balancer Controller annotations)"
  type        = map(string)
  default     = {}
}
