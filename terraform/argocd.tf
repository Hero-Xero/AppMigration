# this creates the dedicated namespace for ArgoCD using the new v1 provider resource
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

# this installs ArgoCD from the official Helm Chart
resource "helm_release" "argocd" {

  depends_on = [helm_release.aws_load_balancer_controller]  
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