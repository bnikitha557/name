#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AWS_DB="$ROOT/aws-db.properties"
PROFILE="aws"

if [[ -f "$AWS_DB" ]]; then
  if grep -q 'YOUR_RDS_MASTER_PASSWORD_HERE' "$AWS_DB" 2>/dev/null; then
    echo "Edit $AWS_DB and set rds.password to your RDS master password."
    exit 1
  fi
elif [[ -z "${RDS_PASSWORD:-}" ]]; then
  echo "RDS password required. Either:"
  echo "  cp aws-db.properties.example aws-db.properties"
  echo "  # edit aws-db.properties -> rds.password=..."
  echo "  OR: export RDS_PASSWORD='your-rds-password'"
  exit 1
fi

echo "Starting auth-service on :8081 (profile=$PROFILE)..."
(cd "$ROOT/authservice" && SPRING_PROFILES_ACTIVE="$PROFILE" ./mvnw -q spring-boot:run) &
AUTH_PID=$!

echo "Waiting for auth-service (up to ~2 min)..."
for i in {1..60}; do
  if curl -sf -o /dev/null -H "Authorization: Bearer demo" http://127.0.0.1:8081/auth/validate 2>/dev/null; then
    echo "Auth is up."
    break
  fi
  if ! kill -0 "$AUTH_PID" 2>/dev/null; then
    echo "Auth process exited. Check logs above for Access denied / wrong password."
    exit 1
  fi
  sleep 2
done

echo "Starting order-service on :8082 (profile=$PROFILE)..."
(cd "$ROOT/ordermanagementsystem" && SPRING_PROFILES_ACTIVE="$PROFILE" ./mvnw -q spring-boot:run) &
ORDER_PID=$!

echo ""
echo "Auth PID:  $AUTH_PID  -> http://localhost:8081"
echo "Order PID: $ORDER_PID -> http://localhost:8082"
echo "Stop: kill $AUTH_PID $ORDER_PID"

wait
