module "load_balancer_controller_irsa_role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version = "5.30.0"

    role_name = "load-balancer-controller-irsa-role"
    attach_load_balancer_controller_policy = true

    oidc_providers = {
        ex = {
            provider_arn = module.eks.oidc_provider_arn
            namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
        }
    }
}


resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  depends_on = [module.eks]
  
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" // we are escaping the dot because Helm uses dot notation for nested values, and we want to set the annotation key literally
    value = module.load_balancer_controller_irsa_role.iam_role_arn
  }
}


# this patches missing permissions for newer versions of the Load Balancer Controller
resource "aws_iam_role_policy" "lbc_patch" {
  name = "lbc-permission-patch"
  # and this targets the role already created via the module
  role = module.load_balancer_controller_irsa_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeCapacityReservation",
          "ec2:DescribeRouteTables"
        ]
        Resource = "*"
      }
    ]
  })
}