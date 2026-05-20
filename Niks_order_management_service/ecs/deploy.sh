#!/usr/bin/env bash
# Deploy OMS to ECS Fargate in us-east-2 (Ohio).
# ECS must run in the SAME VPC as RDS (not necessarily the default VPC).
set -euo pipefail

REGION="${AWS_REGION:-us-east-2}"
STACK_NAME="${STACK_NAME:-oms-ecs}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CF_TEMPLATE="$SCRIPT_DIR/cloudformation/oms-ecs.yaml"

RDS_ENDPOINT="${RDS_ENDPOINT:-database-1.cpqysuqqqw39.us-east-2.rds.amazonaws.com}"
RDS_SG_ID="${RDS_SG_ID:-sg-026be8a967d35b2da}"

if [[ -z "${RDS_PASSWORD:-}" ]]; then
  if [[ -f "$ROOT/aws-db.properties" ]] && grep -q '^rds.password=' "$ROOT/aws-db.properties"; then
    RDS_PASSWORD="$(grep '^rds.password=' "$ROOT/aws-db.properties" | cut -d= -f2-)"
  else
    echo "Set RDS password: export RDS_PASSWORD='...'  (or use aws-db.properties)"
    exit 1
  fi
fi

STACK_STATUS="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" \
  --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")"

if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]]; then
  echo "Stack $STACK_NAME is ROLLBACK_COMPLETE — deleting before redeploy..."
  aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK_NAME"
  aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK_NAME"
  echo "Delete complete."
fi

echo "Using VPC from RDS security group $RDS_SG_ID ..."
VPC_ID="$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$RDS_SG_ID" \
  --query 'SecurityGroups[0].VpcId' --output text)"

SUBNETS="$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
  --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')"

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" || -z "$SUBNETS" ]]; then
  echo "Could not find public subnets in VPC $VPC_ID."
  echo "Set manually: export VPC_ID=...  export PUBLIC_SUBNETS=subnet-a,subnet-b"
  exit 1
fi

PUBLIC_SUBNETS="${PUBLIC_SUBNETS:-$SUBNETS}"

DEFAULT_VPC="$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"
if [[ "$VPC_ID" != "$DEFAULT_VPC" ]]; then
  echo "NOTE: RDS VPC ($VPC_ID) is NOT the default VPC ($DEFAULT_VPC). Deploying ECS into RDS VPC."
fi

echo "VPC: $VPC_ID"
echo "Subnets: $PUBLIC_SUBNETS"
echo "RDS endpoint: $RDS_ENDPOINT"
echo "RDS SG: $RDS_SG_ID"

aws cloudformation deploy \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$CF_TEMPLATE" \
  --parameter-overrides \
    VpcId="$VPC_ID" \
    PublicSubnetIds="$PUBLIC_SUBNETS" \
    RdsEndpoint="$RDS_ENDPOINT" \
    RdsSecurityGroupId="$RDS_SG_ID" \
    RdsMasterPassword="$RDS_PASSWORD" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

echo ""
echo "=== Stack outputs ==="
aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' --output table

ALB="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" --output text)"

echo ""
echo "Test (wait 2-3 min for tasks to become healthy):"
echo "  curl -s http://$ALB/auth/health"
echo "  curl -s -H 'Authorization: Bearer demo' http://$ALB/auth/validate"
