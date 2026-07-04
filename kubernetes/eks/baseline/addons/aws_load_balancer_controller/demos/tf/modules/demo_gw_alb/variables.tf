variable "namespace" {
  description = "Namespace to deploy the demo into. Created automatically unless it's \"default\" (which always exists)."
  type        = string
  default     = "default"
}

variable "app_name" {
  description = "Name shared by the Deployment, Service, and derived Gateway/route resources"
  type        = string
  default     = "demo-gwhttp-app"
}

variable "image" {
  description = "Container image for the demo app"
  type        = string
  default     = "nginx:alpine"
}

variable "hostname" {
  description = "Host used for HTTPRoute host-based routing"
  type        = string
  default     = "demo.example.com"
}

variable "gateway_class_name" {
  description = "Name of the cluster-scoped GatewayClass this module creates. Only instantiate this module once per cluster, or override this to avoid a name collision."
  type        = string
  default     = "aws-alb"
}
