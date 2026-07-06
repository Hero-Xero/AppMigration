#!/bin/bash
set -e
echo "Starting Optimized Teardown..."

REGION="us-east-1"
CLUSTER_NAME="app-migration"
VPC_TAG_NAME="app-migration-vpc"

# 1. Graceful Kubernetes Cleanup
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null || true
echo "Deleting Kubernetes Ingresses and LoadBalancers..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=30s 2>/dev/null || true
kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true --timeout=30s 2>/dev/null || true

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_TAG_NAME" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

echo "Found VPC Target: $VPC_ID"

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "Pre-clean: Eliminating ELB resources..."
  
  # Delete Load Balancers
  LB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || echo "")
  for ARN in $LB_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ARN" || true
  done
  
  # Delete Target Groups
  TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text 2>/dev/null || echo "")
  for ARN in $TG_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$ARN" 2>/dev/null || true
  done

  echo "Pre-clean: Sweeping target VPC for leftover ghost dependencies..."

  # Force delete any leftover ENIs
  ENIS=$(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null || echo "")
  for ENI in $ENIS; do
    if [ -n "$ENI" ]; then
      aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$ENI" 2>/dev/null || true
    fi
  done

  # Break cyclic security group references and delete them BEFORE Terraform runs
  SGS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
  for SG in $SGS; do
    if [ -n "$SG" ]; then
      aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$SG" --ingress json='[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]' 2>/dev/null || true
      aws ec2 revoke-security-group-egress --region "$REGION" --group-id "$SG" --ingress json='[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]' 2>/dev/null || true
      aws ec2 delete-security-group --region "$REGION" --group-id "$SG" 2>/dev/null || true
    fi
  done
fi

# 2. Execute Terraform Destroy
cd terraform || exit 1
terraform init -input=false

if ! terraform plan -destroy -lock-timeout=10s -input=false >/tmp/tf_plan_check.log 2>&1; then
  if grep -q "Lock Info" /tmp/tf_plan_check.log; then
    LOCK_ID=$(grep -oP 'ID:\s+\K[a-f0-9-]+' /tmp/tf_plan_check.log || echo "")
    echo "State locked, unlocking: $LOCK_ID"
    [ -n "$LOCK_ID" ] && terraform force-unlock -force "$LOCK_ID"
  fi
fi

echo "Running Terraform Destroy..."
terraform destroy -auto-approve