module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = "app-migration"
  cluster_version = "1.36"

  vpc_id = aws_vpc.main.id

  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    app_nodes = { 
      instance_types = ["t3.small"]
      min_size     = 2
      max_size     = 4
      desired_size = 3
      vpc_security_group_ids = [aws_security_group.eks_nodes.id]
    }
  }
}