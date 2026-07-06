resource "kubernetes_secret_v1" "app_secrets" {
  metadata {
    name      = "app-secrets"
    namespace = "default"
  }

  data = {
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/${aws_db_instance.postgres.db_name}"
    SPRING_DATASOURCE_USERNAME = aws_db_instance.postgres.username
    SPRING_DATASOURCE_PASSWORD = random_password.db_password.result
  }

  depends_on = [
    module.eks,
    aws_db_instance.postgres
  ]
}