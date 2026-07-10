variable "namespace" {
  description = "Namespace to deploy the demo into. Created automatically unless it's \"default\" (which always exists)."
  type        = string
  default     = "default"
}

variable "app_name" {
  description = "Name shared by the Deployment and Service"
  type        = string
  default     = "demo-nlb-app"
}

variable "image" {
  description = "Container image for the demo app"
  type        = string
  default     = "nginx:alpine"
}
