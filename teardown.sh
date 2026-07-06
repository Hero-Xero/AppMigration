#!/bin/bash
set -e
echo "Starting Teardown..."

REGION="us-east-1"
CLUSTER_NAME="app-migration"
VPC_TAG_NAME="app-migration-vpc"

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null || true
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=60s 2>/dev/null || true
kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true --timeout=60s 2>/dev/null || true

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_TAG_NAME" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

echo "Found VPC: $VPC_ID"

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  LB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || echo "")

  if [ -n "$LB_ARNS" ]; then
    for ARN in $LB_ARNS; do
      echo "Deleting LB: $ARN"
      aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ARN" || true
    done
    echo "Waiting for LB ENIs to release..."
    for i in $(seq 1 20); do
      ENI_COUNT=$(aws ec2 describe-network-interfaces --region "$REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=ELB*" \
        --query 'length(NetworkInterfaces)' --output text 2>/dev/null || echo "0")
      [ "$ENI_COUNT" = "0" ] && break
      echo "  $ENI_COUNT ENI(s) remaining ($i/20)"
      sleep 30
    done
  else
    echo "No load balancers found — nothing to clean."
  fi

  TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" \
    --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text 2>/dev/null || echo "")
  for ARN in $TG_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$ARN" 2>/dev/null || true
  done
else
  echo "VPC not found — already destroyed. Skipping AWS cleanup."
fi

cd terraform || exit 1
terraform init -input=false

if ! terraform plan -destroy -lock-timeout=10s -input=false >/tmp/tf_plan_check.log 2>&1; then
  if grep -q "Lock Info" /tmp/tf_plan_check.log; then
    LOCK_ID=$(grep -oP 'ID:\s+\K[a-f0-9-]+' /tmp/tf_plan_check.log || echo "")
    echo "State locked from interrupted run, unlocking: $LOCK_ID"
    [ -n "$LOCK_ID" ] && terraform force-unlock -force "$LOCK_ID"
  fi
fi

terraform destroy -auto-approve