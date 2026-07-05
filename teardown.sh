#!/bin/bash

echo "Starting Idempotent Teardown..."

# 1. Refresh context but ignore failures
echo "Refreshing local Kubernetes context..."
aws eks update-kubeconfig --region us-east-1 --name app-migration || true

# Attempt clean Kubernetes cleanup, ignore if Unauthorized
echo "Attempting to delete ingress resources..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=30s || echo "⚠️ Kubernetes API unreachable. Skipping clean ingress deletion."

cd terraform || exit

# Check if Terraform backend is functional
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init -backend=false || true
fi

# FORCE REMOVE ALL HELM AND KUBERNETES FROM STATE
# We must wipe every single Kubernetes resource from Terraform's memory 
# so it doesn't try to authenticate to the dead cluster.
echo "Purging Kubernetes resources from Terraform state..."
terraform state rm helm_release.aws_load_balancer_controller 2>/dev/null || true
terraform state rm kubernetes_namespace_v1.argocd 2>/dev/null || true
terraform state rm helm_release.prometheus 2>/dev/null || true

# 5. Final AWS Infrastructure Destruction
echo "Destroying physical AWS infrastructure..."
terraform destroy -auto-approve