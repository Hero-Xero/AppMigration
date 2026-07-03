# this creates the dedicated namespace for ArgoCD using the new v1 provider resource
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

# this installs ArgoCD from the official Helm Chart
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.3.1" 
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name   # this reference points to the new v1 resource block


  set {
    name  = "server.insecure"
    value = "true"
  }
}