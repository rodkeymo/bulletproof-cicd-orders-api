# orders-api — CI/CD Reference Project

A minimal Node/Express service used to demonstrate a **bulletproof CI/CD
pipeline on AWS**: Docker → ECR → ECS Fargate, provisioned with Terraform,
deployed through a gated multi-stage GitHub Actions pipeline.

This is the companion project for the talk *"From Zero to Production:
Building Bulletproof CI/CD Pipelines on AWS for SaaS Platforms."*

## Architecture

```
GitHub Actions                     AWS
───────────────                    ───
PR opened
  └─ test gate (lint + unit tests)

Merge to main
  ├─ build gate  ──────────────►  ECR (image tagged with git SHA)
  │                                 └─ vulnerability scan gate
  ├─ deploy: staging ───────────►  ECS Fargate (staging cluster)
  │                                 └─ smoke test gate (curl /health)
  └─ deploy: production ────────►  ECS Fargate (production cluster)
        (manual approval)           behind an Application Load Balancer
                                     └─ autoscaling on CPU (target 60%)
```

Terraform provisions everything on the AWS side: VPC, ALB, ECS
cluster/service/task definition, ECR repo, IAM roles, autoscaling policy,
and CloudWatch log group. Nothing is clicked in the console.

## Why these choices

| Decision | Reasoning |
|---|---|
| **Fargate over EC2-backed ECS** | No node patching, no capacity planning for a service this size. Trade cost-per-vCPU for zero ops overhead. |
| **ECS over Lambda** | Long-lived HTTP service with steady traffic — avoids cold starts and the 15-min execution ceiling Lambda would impose. |
| **Image tagged by git SHA, never `latest`** | Every running task is traceable to an exact commit. Rollback = redeploy the previous SHA's task definition. |
| **Staging deploy is automatic, production requires approval** | Bad code should die in staging, not at 2am in prod. The approval gate is a GitHub Environment protection rule, not a Slack message someone forgets to send. |
| **OIDC federation instead of static AWS keys in GitHub secrets** | Removes long-lived credentials from CI entirely. |

## Repo layout

```
src/                   Express app (health/readiness probes + orders API)
tests/                 Jest + supertest unit tests
terraform/             Infra as code (VPC, ECR, ECS, ALB, IAM, autoscaling)
.github/workflows/
  ci-cd.yml            App pipeline: test -> build -> deploy staging -> deploy prod
  terraform.yml        Infra pipeline: plan on PR -> apply on merge (approval-gated)
Dockerfile             Multi-stage build, non-root user, container healthcheck
```

## Running locally

```bash
npm install
npm test
npm start        # http://localhost:3000/health
```

```bash
docker build -t orders-api .
docker run -p 3000:3000 orders-api
```

## Deploying to AWS

1. Create an S3 bucket + DynamoDB table for Terraform remote state, and
   update `terraform/versions.tf` with those names.
2. Set up an IAM role for GitHub OIDC (`AWS_DEPLOY_ROLE_ARN` repo secret).
3. Copy `terraform/environments/staging.tfvars.example` and
   `production.tfvars.example`, drop the `.example` suffix, adjust values.
4. `cd terraform && terraform init && terraform apply -var-file=environments/staging.tfvars`
5. Create `staging` and `production` GitHub Environments; add a required
   reviewer to `production` — that's the manual gate in `ci-cd.yml`.
6. Push to `main`. Watch the pipeline run through all four gates.

## What "bulletproof" means here

- **Test gate**: nothing builds unless lint + unit tests pass.
- **Build gate**: image is vulnerability-scanned before it's eligible to deploy.
- **Staging gate**: real smoke test against a real running service, not a mock.
- **Production gate**: human-approved, deployed with `wait-for-service-stability`
  so the pipeline fails loudly if the new tasks never go healthy — instead of
  silently leaving a broken rolling deploy half-finished.
