#!/bin/bash
set -e

# THE NUKE: Disables AWS CLI pagination globally for this script only. 
# It will not leak into your host terminal.
export AWS_PAGER=""

echo "Starting Optimized Teardown..."

REGION="us-east-1"
CLUSTER_NAME="app-migration"
VPC_TAG_NAME="app-migration-vpc"

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null || true
echo "Deleting Kubernetes Ingresses and LoadBalancers..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=30s 2>/dev/null || true
kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true --timeout=30s 2>/dev/null || true

sweep_vpc_dependencies() {
  local VPC_ID
  VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Name,Values=$VPC_TAG_NAME" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

  echo "Found VPC Target: $VPC_ID"
  [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ] && { echo "VPC not found — nothing to sweep."; return 0; }

  echo "Sweep: Eliminating ELB resources..."
  LB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || echo "")
  for ARN in $LB_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ARN" || true
  done
  [ -n "$LB_ARNS" ] && sleep 20

  TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text 2>/dev/null || echo "")
  for ARN in $TG_ARNS; do
    [ -n "$ARN" ] && aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$ARN" 2>/dev/null || true
  done

  echo "Sweep: Force-deleting unattached ENIs..."
  ENIS=$(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null || echo "")
  for ENI in $ENIS; do
    [ -n "$ENI" ] && aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$ENI" 2>/dev/null || true
  done

  echo "Sweep: Breaking SG cross-references and deleting non-default SGs..."
  for i in $(seq 1 6); do
    SGS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
    [ -z "$SGS" ] && { echo "No non-default SGs remaining."; break; }

    for SG in $SGS; do
      # Strip CIDR-based rules
      aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$SG" --ip-permissions "$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$SG" --query 'SecurityGroups[0].IpPermissions' --output json)" 2>/dev/null || true
      aws ec2 revoke-security-group-egress --region "$REGION" --group-id "$SG" --ip-permissions "$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$SG" --query 'SecurityGroups[0].IpPermissionsEgress' --output json)" 2>/dev/null || true

      # Strip rules in OTHER SGs that reference this SG
      REF_SGS=$(aws ec2 describe-security-groups --region "$REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=ip-permission.group-id,Values=$SG" \
        --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")
      for REF in $REF_SGS; do
        [ "$REF" == "$SG" ] && continue
        aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$REF" \
          --ip-permissions "$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$REF" --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$SG']]" --output json)" 2>/dev/null || true
      done

      aws ec2 delete-security-group --region "$REGION" --group-id "$SG" 2>/dev/null || true
    done
    sleep 8
  done
}

sweep_vpc_dependencies

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
for attempt in 1 2 3; do
  if terraform destroy -auto-approve 2>/tmp/tf_destroy.log; then
    echo "Teardown complete."
    exit 0
  fi

  if grep -q "DependencyViolation" /tmp/tf_destroy.log; then
    echo "Attempt $attempt hit DependencyViolation — re-sweeping VPC and retrying..."
    cd ..
    sweep_vpc_dependencies
    cd terraform
  else
    echo "Destroy failed for a reason other than DependencyViolation — inspect /tmp/tf_destroy.log"
    cat /tmp/tf_destroy.log
    exit 1
  fi
done

echo "Still failing after 3 attempts — inspect /tmp/tf_destroy.log"
exit 1