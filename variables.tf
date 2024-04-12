variable "instance_types" {
  type    = list(string)
  default = ["t3.medium", "t3a.medium"]
}

variable "eks_version" {
  type    = string
  default = "1.28"
}

variable "cluster_name" {
  type    = string
  default = "apps"
}

variable "instance_capacity_type" {
  type    = string
  default = "SPOT"
}

variable "region" {
  type    = string
  default = "us-east-1"
}