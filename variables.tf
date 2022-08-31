variable "region" {
  default = "ca-central-1"
}

variable "cluster_name_prefix" {
  description = "Value to prepend to cluster names"
  default = "syzygy-eks"
}

variable "worker_node_group_node_type" {
  description = "AWS Node type for user pod nodes"
  default = "m5.large"
}

variable "worker_node_group_min_size" {
  description = "Minimum size for scaling group"
  default = "0"
}

variable "worker_node_group_max_size" {
  description = "Maximum size for scaling group"
  default = "4"
}

variable "worker_node_group_desired_size" {
  description = "Maximum size for scaling group"
  default = "1"
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {
      "Project" = "Syzygy"
  }
}

variable "cluster_version" {
  description = "Version of k8s to deploy"
  default = "1.22"
}
