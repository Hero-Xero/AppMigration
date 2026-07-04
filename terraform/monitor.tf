resource "helm_release" "prometheus" {

  depends_on = [helm_release.aws_load_balancer_controller]

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "61.3.0"
}