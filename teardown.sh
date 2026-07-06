#!/bin/bash
set -e
echo "Starting Teardown..."

REGION="us-east-1"
CLUSTER_NAME="app-migration"
VPC_TAG_NAME="app-migration-vpc"

# 1. Graceful Kubernetes Cleanup
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null || true
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=60s 2>/dev/null || true
kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true --timeout=60s 2>/dev/null || true

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_TAG_NAME" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

echo "Found VPC: $VPC_ID"

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  
  # 2. Hard Kill: Load Balancers
  LB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || echo "")
  for ARN in $LB_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ARN" || true
  done

  # 3. Hard Kill: Target Groups
  TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" \
    --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text 2>/dev/null || echo "")
  for ARN in $TG_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$ARN" 2>/dev/null || true
  done

  # 4. Hard Kill: Ghost ENIs (Force delete instead of just waiting)
  echo "Executing leftover Load Balancer ENIs..."
  ENIS=$(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=ELB*" \
    --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null || echo "")
  for ENI in $ENIS; do
    [ -n "$ENI" ] && aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$ENI" 2>/dev/null || true
  done

  # 5. Hard Kill: Ghost Security Groups (The VPC blocker)
  echo "Executing leftover Kubernetes Security Groups..."
  SGS=$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[?starts_with(GroupName, 'k8s-')].GroupId" --output text 2>/dev/null || echo "")
  for SG in $SGS; do
    [ -n "$SG" ] && aws ec2 delete-security-group --region "$REGION" --group-id "$SG" 2>/dev/null || true
  done

else
  echo "VPC not found — already destroyed. Skipping AWS cleanup."
fi

# 6. Terraform Execution
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