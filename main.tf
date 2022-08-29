terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.13.0"
    }
  }
}

provider "aws" {
    region  = var.region
    profile = var.profile
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

locals {
  cluster_name = "syzygy-eks-${random_string.suffix.result}"
  cluster_version = "1.22"
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
}

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length = 8
  special = false
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16"
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name                 = local.cluster_name
  cidr                 = "10.1.0.0/16"

  azs                  = ["${var.region}a", "${var.region}b"]

  private_subnets      = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets       = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}


module "eks" {

  source       = "terraform-aws-modules/eks/aws"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      #service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  cluster_encryption_config = [{
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
  }]

  cluster_tags = {
    Name = local.cluster_name
  }

  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  self_managed_node_group_defaults = {
    create_security_group = false

    # enable discovery of autoscaling groups by cluster-autoscaler
    autoscaling_group_tags = {
      "k8s.io/cluster-autoscaler/enabled" : true,
      "k8s.io/cluster-autoscaler/${local.cluster_name}" : "owned",
    }
  }

  self_managed_node_groups = {

    default_node_group = {}

    workers = {
      name                          = "worker-group-1"
      instance_type                 = var.worker_group_user_node_type
      desired_capacity              = var.worker_group_desired_capacity
      min_size                      = var.worker_group_min_size
      max_size                      = var.worker_group_max_size

      ami_id  = data.aws_ami.eks_default.id

      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]

      bootstrap_extra_args = <<-EOT
      # The admin host container provides SSH access and runs with "superpowers".
      # It is disabled by default, but can be disabled explicitly.
      [settings.host-containers.admin]
      enabled = false
      # The control host container provides out-of-band access via SSM.
      # It is enabled by default, and can be disabled if you do not expect to use SSM.
      # This could leave you with no way to access the API and change settings on an existing node!
      [settings.host-containers.control]
      enabled = true

      [settings.kubernetes.node-labels]
      "hub.jupyter.org/node-purpose" = "user"
      ingress = "allowed"

      [settings.kubernetes.node-taints]
      "hub.jupyter.org/dedicated=user" = "user:NoSchedule"
      EOT
    }
  }
}

resource "aws_efs_file_system" "home" {
}

resource "aws_efs_mount_target" "home_mount" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.home.id
  subnet_id       = element(module.vpc.private_subnets, count.index)
  security_groups = [aws_security_group.efs_mt_sg.id]
}

resource "aws_security_group" "efs_mt_sg" {
  name_prefix = "efs_mt_sg"
  description = "Allow NFSv4 traffic"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"

    cidr_blocks = [
      "10.1.0.0/16"
    ]
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

# This policy is required for the KMS key used for EKS root volumes, so the cluster is allowed to enc/dec/attach encrypted EBS volumes
data "aws_iam_policy_document" "ebs" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Required for EKS
  statement {
    sid = "Allow service-linked role use of the CMK"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }
  }

  statement {
    sid       = "Allow attachment of persistent resources"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}
