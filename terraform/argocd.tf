# this creates the dedicated namespace for ArgoCD using the new v1 provider resource
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.eks]
}

# this installs ArgoCD from the official Helm Chart
resource "helm_release" "argocd" {
  depends_on = [helm_release.aws_load_balancer_controller]
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.3.1"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        insecure = true
        extraArgs = ["--insecure"]
        # Disable the chart's broken template entirely
        ingress  = { enabled = false }  
      }
    })
  ]
}

# Define the custom Ingress manually
resource "kubernetes_ingress_v1" "argocd_custom" {
  metadata {
    name      = "argocd-server-custom"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/success-codes"    = "200,307"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80 # Explicitly target the insecure HTTP port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# Fetch the URL from our new custom Ingress
data "kubernetes_ingress_v1" "argocd_url_fetcher" {
  metadata {
    name      = kubernetes_ingress_v1.argocd_custom.metadata[0].name
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  depends_on = [kubernetes_ingress_v1.argocd_custom]
}

# because terraform applies resources in parallel, it won't know waht an application is until Helm Chart is fully installed.
# hence the "null_resource", which is used to wait for the Helm Chart to finish before applying the ArgoCD application manifest.
resource "null_resource" "bootstrap_argocd" {
  # And this forces Terraform to wait until the Helm chart finishes.
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {

    command = <<EOT
      aws eks update-kubeconfig --region us-east-1 --name app-migration
      kubectl apply -f ../argocd-app.yaml
    EOT
  }
}


# Fetch the auto-generated password secret from Kubernetes
data "kubernetes_secret_v1" "argocd_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  
  depends_on = [helm_release.argocd]
}
