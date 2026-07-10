variable "role_arn" {
  description = "ARN of the IAM role to annotate onto the controller's service account for IRSA (from the lbc_irsa module). Leave null when using EKS Pod Identity instead -- the lbc_podid module's association handles the IAM binding out-of-band, with no ServiceAccount annotation needed."
  type        = string
  default     = null
}

variable "use_experimental_gateway_api" {
  description = "Install the Gateway API experimental channel CRDs instead of the standard channel. Only one channel may be installed at a time."
  type        = bool
  default     = true
}
