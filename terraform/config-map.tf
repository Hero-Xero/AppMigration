resource "kubernetes_config_map_v1" "grafana_dashboards" {
  metadata {
    name      = "grafana-custom-dashboards"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "my-app-dashboard.json" = file("${path.module}/../dashboards/app_dashboard.json")
  }

  depends_on = [
    helm_release.prometheus
  ]
}