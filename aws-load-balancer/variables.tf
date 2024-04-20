variable "oidc_provider_arn" {
  type        = string
  description = "oidc provider arn"
}

variable "oidc_provider" {
  type        = string
  description = "OpenID Connect identity provider url"
}

variable "cluster_name" {
  type        = string
  description = "cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "endpoint of cluster"
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "cluster certificate authority data"
}

variable "service_account_name" {
  type = string
  description = "name of service account used by load balancer controller"
  default = "aws-lb-controller"
}