output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks.aws_auth_configmap_yaml
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "cluster_name" {
  description = "AWS EKS cluster name"
  value       = module.eks.cluster_id
}

output "efs_id" {
  description = "AWS EFS FileSystemID"
  value       = aws_efs_file_system.home.id
}

output "vpc_id" {
  description = "VPC"
  value       = module.vpc.vpc_id
}

output "subnet_id" {
  description = "Publicly accessible subnet inside our VPC"
  value       = module.vpc.public_subnets[0]
}
