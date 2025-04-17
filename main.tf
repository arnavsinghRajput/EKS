provider "aws" {
  region = "ap-south-1"
}

variable "cluster_name" {
  default = "free-tier-eks"
}

variable "admin_role_arn" {
  default = "arn:aws:iam::910342001130:role/adminrole"
}

variable "vpc_id" {
  default = "vpc-0fb96c7a550c3dd8d"
}

variable "subnet_ids" {
  default = [
    "subnet-025d774bc5f212254", # ap-south-1a
    "subnet-00b4a69d906f64d9e"  # ap-south-1b
  ]
}

# Security Group
resource "aws_security_group" "eks_sg" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow all traffic for EKS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = var.admin_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
    security_group_ids      = [aws_security_group.eks_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "free-tier-ng"
  node_role_arn   = var.admin_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.micro"]
  depends_on     = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.worker_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.worker_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.worker_AmazonEC2ContainerRegistryReadOnly
  ]
}

# aws-auth config map to allow your IAM role
resource "null_resource" "update_aws_auth" {
  depends_on = [aws_eks_node_group.node_group]

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --region ap-south-1 --name ${var.cluster_name}
      kubectl apply -f aws-auth.yaml
    EOT
  }
}

# Create the aws-auth.yaml file
resource "local_file" "aws_auth" {
  content = <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${var.admin_role_arn}
      username: admin
      groups:
        - system:masters
EOT

  filename = "${path.module}/aws-auth.yaml"
}

# IAM Policy Attachments for adminrole
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

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ap-south-1 --name ${var.cluster_name}"
}
