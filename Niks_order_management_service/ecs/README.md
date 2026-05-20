# Deploy Auth + Order to AWS ECS (Fargate)

## Architecture

```
Internet → ALB (port 80)
              ├── /auth*  → Auth task :8081  → RDS auth_service
              └── /orders* → Order task :8082 → RDS order_management_service
                                    │
                                    └── Feign → http://auth-service.oms.local:8081
                                         (Cloud Map service discovery)
```

## CI/CD (GitHub Actions)

Workflows live in the repo root `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `oms-ci.yml` | PR / push to `feature/hmi-123main` or `main` | Maven tests (Java 17, in-memory H2) |
| `oms-cd.yml` | Push to `feature/hmi-123main` or `main` / manual | Build & push Docker images; redeploy ECS |

### Enable automatic deploy (one-time)

1. Open **GitHub → bnikitha557/name → Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Value |
|--------|--------|
| `DOCKERHUB_USERNAME` | `nikithabandi` (your Docker Hub user) |
| `DOCKERHUB_TOKEN` | Docker Hub → Account Settings → **Security** → New Access Token (read/write) |
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

2. IAM user policy (minimum) for the ECS redeploy step:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": "*"
    }
  ]
}
```

3. Push to `feature/hmi-123main` (or run **Actions → OMS CD → Run workflow** manually).

Images pushed: `nikithabandi/auth-service:latest`, `nikithabandi/order-service:latest` (same as CloudFormation defaults). ECS cluster `oms-cluster`, services `oms-auth` and `oms-order` in `us-east-2`.

## Prerequisites

1. **AWS CLI** logged in (`aws sts get-caller-identity`)
2. **Region** `us-east-2` (same as RDS)
3. **RDS** `database-1` in the **default VPC** (or note your VPC + subnets)
4. **Docker Hub images** pushed:
   - `nikithabandi/auth-service:latest`
   - `nikithabandi/order-service:latest`
5. Rebuild images after adding `application-ecs.properties`:
   ```bash
   cd authservice && docker build -t nikithabandi/auth-service:latest . && docker push nikithabandi/auth-service:latest
   cd ordermanagementsystem && docker build -t nikithabandi/order-service:latest . && docker push nikithabandi/order-service:latest
   ```

## Step 1 — Get RDS security group ID

RDS Console → **database-1** → **Connectivity & security** → click the **VPC security group** → copy **Security group ID** (`sg-...`).

```bash
export RDS_SG_ID=sg-xxxxxxxx
```

## Step 2 — Deploy stack

```bash
cd /path/to/Niks_order_management_service/ecs
chmod +x deploy.sh

export RDS_SG_ID=sg-xxxxxxxx
# Password from aws-db.properties or:
# export RDS_PASSWORD='your-rds-password'

./deploy.sh
```

Wait until ECS services show **running** tasks and ALB targets are **healthy** (2–5 minutes).

## Step 3 — Test via ALB

```bash
ALB=$(aws cloudformation describe-stacks --stack-name oms-ecs --region us-east-2 \
  --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" --output text)

curl -s -H "Authorization: Bearer demo" "http://$ALB/auth/validate"
curl -s -X POST "http://$ALB/orders" \
  -H "Authorization: Bearer demo" \
  -H "Content-Type: application/json" \
  -d '{"productName":"iPhone","quantity":1,"price":1200}'
```

## Logs

```bash
aws logs tail /ecs/oms-auth --follow --region us-east-2
aws logs tail /ecs/oms-order --follow --region us-east-2
```

## Tear down

```bash
aws cloudformation delete-stack --stack-name oms-ecs --region us-east-2
```

## Interview talking points

- **ECS Fargate** runs containers without managing EC2.
- **ALB** routes public HTTP to each service.
- **Cloud Map** (`auth-service.oms.local`) lets Order call Auth inside the VPC.
- **Security groups**: ALB → tasks; tasks → RDS on 3306 only.
- **RDS password** should move to **Secrets Manager** (template currently uses a stack parameter).

## Troubleshooting

| Issue | Fix |
|--------|-----|
| Tasks keep restarting | Check CloudWatch logs; often RDS password or SG |
| Target unhealthy | Wait 120s grace period; check logs |
| Order 401 / Feign error | Auth service not registered in Cloud Map yet; wait for auth task healthy |
| Cannot pull image | Tasks need public IP or NAT; template uses public subnets + AssignPublicIp |
| RDS connection refused | Confirm `RdsIngressFromEcs` rule on RDS SG (stack adds it) |
