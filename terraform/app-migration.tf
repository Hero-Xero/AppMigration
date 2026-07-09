data "kubernetes_ingress_v1" "app_migration" {
  metadata {
    name      = "app-migration-ingress"
    namespace = "default"
  }
  depends_on = [null_resource.bootstrap_argocd]
}

resource "time_sleep" "wait_for_app_alb" {
  depends_on      = [data.kubernetes_ingress_v1.app_migration]
  create_duration = "30s"
}