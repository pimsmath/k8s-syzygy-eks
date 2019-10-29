variable "region" {
  default = "us-west-2"
}

variable "profile" {
  description = "AWS profile to use for authentication"
  default     = "iana"
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
