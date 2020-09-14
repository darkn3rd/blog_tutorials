#####################################################################
## Variables
#####################################################################
variable "access_key" {}
variable "secret_key" {}

## Optional Variables
variable "replicas" {
  default     = 1
  description = "Number of MinIO servers created with Helm Chart"
}

variable "tag" {
  default     = "RELEASE.2020-09-08T23-05-18Z"
  description = "Docker tag"
}

variable "minio_host" {
  default     = "localhost"
  description = "Minio Host name used in configuration"
}

variable "compose_env_path" {
  default     = ""
  description = "Create Docker Compose .env file if path defined"
}

variable "helm_chart_secrets_path" {
  default     = ""
  description = "Create Helm chart config values if path defined"
}

variable "helm_chart_config_path" {
  default     = ""
  description = "Create Helm chart secrets values if path defined"
}

variable "s3cfg_path" {
  default     = ""
  description = "Create s3cfg file if path defined.  This should be copied to ~/.s3cfg"
}
