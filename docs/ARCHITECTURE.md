# AviQuest Cloud Architecture

## Overview

AviQuest uses a serverless AWS architecture designed for scalability, cost-efficiency, and low operational overhead. The infrastructure is defined entirely as code using Terraform, with multi-environment support (dev/staging/prod).

## Architecture Diagram

```
                    ┌──────────────────────────────────────────────┐
                    │              Flutter Mobile App               │
                    │  (Android / iOS)                             │
                    └──────────┬──────────────┬────────────────────┘
                               │              │
                    ┌──────────▼──────┐  ┌────▼──────────────────┐
                    │   Cognito Auth   │  │  CloudFront CDN       │
                    │   (JWT tokens)   │  │  (Bird images/audio)  │
                    └──────────┬──────┘  └────┬──────────────────┘
                               │              │
                    ┌──────────▼──────┐  ┌────▼──────────────────┐
                    │  API Gateway     │  │  S3 Assets Bucket     │
                    │  (HTTP API v2)   │  │  (images/, audio/)    │
                    └──┬───────────┬──┘  └───────────────────────┘
                       │           │
              ┌────────▼──┐  ┌────▼────────┐
              │ Birds API  │  │ Users API    │
              │ (Lambda)   │  │ (Lambda)     │
              └────────┬──┘  └────┬────────┘
                       │          │
              ┌────────▼──────────▼────────────────────┐
              │              DynamoDB                    │
              │  ┌─────────┐ ┌────────┐ ┌────────────┐ │
              │  │ Birds   │ │ Users  │ │Collections │ │
              │  └─────────┘ └────────┘ └────────────┘ │
              └────────────────────────────────────────┘
                       │
              ┌────────▼──────────────────────────────┐
              │           CloudWatch                    │
              │  Dashboard │ Alarms │ Logs │ SNS       │
              └────────────────────────────────────────┘
```

## AWS Services

| Service | Purpose | Module |
|---------|---------|--------|
| **S3** | Store bird images and audio files | `cdn` |
| **CloudFront** | CDN for low-latency asset delivery worldwide | `cdn` |
| **DynamoDB** | Bird catalog, user profiles, and collections | `database` |
| **Cognito** | User authentication with email/password and MFA | `auth` |
| **API Gateway** | HTTP API with JWT authorization and rate limiting | `api` |
| **Lambda** | Serverless backend functions (Node.js 20.x) | `api` |
| **CloudWatch** | Dashboards, metrics, alarms, and log aggregation | `monitoring` |
| **SNS** | Alarm notifications | `monitoring` |

## Data Model

### Birds Table
- **Primary Key**: `bird_id` (String)
- **GSI**: `rarity-index` (rarity -> all attributes)
- **GSI**: `habitat-index` (habitat -> all attributes)
- **Attributes**: name, scientific_name, image_url, audio_url, lore, habitat, conservation_status, rarity, base_xp

### Users Table
- **Primary Key**: `user_id` (String, from Cognito sub)
- **GSI**: `leaderboard-index` (total_xp -> user_id, username, level, collection_count)
- **Attributes**: username, total_xp, level, collection_count, created_at

### Collections Table
- **Primary Key**: `user_id` (partition) + `bird_id` (sort)
- **Attributes**: found_at, xp_earned

## API Endpoints

### Public (no auth required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/birds` | List all birds (paginated) |
| GET | `/birds/{bird_id}` | Get single bird details |
| GET | `/birds/rarity/{rarity}` | Filter birds by rarity tier |
| GET | `/leaderboard` | Get top players by XP |

### Authenticated (JWT required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/users/profile` | Get current user's profile |
| GET | `/users/collection` | Get user's bird collection |
| POST | `/users/collection` | Add a bird to collection |

## Environment Strategy

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| DynamoDB Billing | PAY_PER_REQUEST | PAY_PER_REQUEST | PROVISIONED |
| CloudFront Price Class | PriceClass_100 | PriceClass_100 | PriceClass_All |
| API Rate Limit | 10 req/s | 10 req/s | 50 req/s |
| API Burst Limit | 20 | 20 | 100 |
| Log Retention | 14 days | 14 days | 90 days |
| PITR (DynamoDB) | Off | Off | On |
| Alarm Thresholds | Relaxed | Relaxed | Strict |

## Cost Estimate (Monthly)

### Dev Environment (~$5-15/month)
- DynamoDB (on-demand): ~$1-5 (minimal usage)
- Lambda: Free tier covers most dev usage
- S3: ~$1 (small asset storage)
- CloudFront: ~$1-5 (low traffic)
- API Gateway: ~$1 (low request volume)

### Prod Environment (~$50-200/month at moderate scale)
- DynamoDB (provisioned): ~$15-30
- Lambda: ~$5-20 (based on invocations)
- S3: ~$5-10 (393 birds * images + audio)
- CloudFront: ~$10-50 (depending on traffic)
- API Gateway: ~$5-20
- CloudWatch: ~$5-10
- Cognito: Free for first 50K MAUs

## Deployment

### Prerequisites
1. AWS account with programmatic access
2. Terraform >= 1.5.0 installed
3. S3 bucket for Terraform state (`aviquest-terraform-state`)
4. DynamoDB table for state locking (`aviquest-terraform-locks`)

### Deploy Infrastructure
```bash
cd infrastructure/terraform

# Initialize with environment backend
terraform init -backend-config=environments/dev/backend.hcl

# Plan changes
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply
terraform apply -var-file=environments/dev/terraform.tfvars
```

### CI/CD Pipelines
- **Flutter CI**: Runs on changes to `aviquest/` — analyzes, tests, and builds APK
- **Infrastructure CI**: Runs on changes to `infrastructure/` or `backend/` — validates, plans (on PR), and applies (on merge to main)

## Security

- **S3**: Public access blocked; assets served only through CloudFront OAC
- **DynamoDB**: Encryption at rest enabled by default
- **Cognito**: Password policy enforced, optional MFA, no user enumeration
- **API Gateway**: JWT authorization on user endpoints, rate limiting
- **Lambda**: Least-privilege IAM roles scoped to specific DynamoDB tables
- **CloudFront**: HTTPS-only with TLS 1.2+
- **State**: Terraform state encrypted in S3 with DynamoDB locking
