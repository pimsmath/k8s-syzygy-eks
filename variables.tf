variable "region" {
  default = "ca-central-1"
}

variable "profile" {
  description = "AWS profile to use for authentication"
  default     = "default"
}

variable "worker_group_user_node_type" {
  description = "AWS Node type for user pod nodes"
  default     = "t2.medium"
}

variable "worker_group_user_asg_min_size" {
  description = "Minimum size for user node ASG"
  default     = "0"
}

variable "worker_group_user_asg_max_size" {
  description = "Maximum size for user node ASG"
  default     = "4"
}

variable "worker_group_user_asg_desired_capacity" {
  description = "Desired capacity for user node ASG"
  default     = "0"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = []
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = []
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
