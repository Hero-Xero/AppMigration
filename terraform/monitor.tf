resource "random_password" "grafana_password" {
  length  = 16
  # FIX 1: Turn off special characters to prevent container crashes
  special = false 
}

resource "helm_release" "prometheus" {
  depends_on = [helm_release.aws_load_balancer_controller]

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "61.3.0"

  values = [
    yamlencode({
      grafana = {
        # 1. Safe password
        adminPassword = random_password.grafana_password.result
        
        # 2. Keep the raw service internal to bypass the NLB block
        service = {
          type = "ClusterIP"
        }
        
        # 3. Use an Ingress to trigger a permitted ALB instead
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
          }
          hosts = []
          paths = ["/"]
        }
      }
    })
  ]
}

data "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "prometheus-grafana"
    namespace = "monitoring"
  }
  depends_on = [helm_release.prometheus]
}