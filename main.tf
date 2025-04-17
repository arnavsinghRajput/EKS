provider "aws" {
  region = "ap-south-1"
}

# Use the given IAM Role ARN
variable "admin_role_arn" {
  default = "arn:aws:iam::910342001130:role/adminrole"
}

resource "aws_eks_cluster" "my_cluster" {
  name     = "free-tier-eks"
  role_arn = var.admin_role_arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "free-tier-nodes"
  node_role_arn   = var.admin_role_arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.micro"]

  depends_on = [
    aws_eks_cluster.my_cluster,
    aws_iam_role_policy_attachment.worker_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.worker_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.worker_AmazonEC2ContainerRegistryReadOnly
  ]
}

# Create a simple VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
}

data "aws_availability_zones" "available" {}

# Attach required EKS policies to adminrole
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = "adminrole"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKSWorkerNodePolicy" {
  role       = "adminrole"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKS_CNI_Policy" {
  role       = "adminrole"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEC2ContainerRegistryReadOnly" {
  role       = "adminrole"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
