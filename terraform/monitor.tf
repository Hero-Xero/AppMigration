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
        adminPassword = random_password.grafana_password.result

         additionalDataSources = [
          {
            name     = "postgres"          # matches the dashboard JSON's datasource.uid reference pattern loosely, but uid is what actually matters
            type     = "postgres"
            uid      = "postgres"           # MUST exactly match every "uid": "postgres" reference in the dashboard JSON above
            url      = aws_db_instance.postgres.address
            port     = 5432
            database = aws_db_instance.postgres.db_name
            user     = aws_db_instance.postgres.username

            secureJsonData = {
              password = random_password.db_password.result
            }

            jsonData = {
              sslmode         = "require"
              postgresVersion = 1600
            }
          }
        ]

        service = {
          type = "ClusterIP"
        }

        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"        = "ip"
            "alb.ingress.kubernetes.io/healthcheck-path"   = "/api/health"
            "alb.ingress.kubernetes.io/success-codes"      = "200"
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