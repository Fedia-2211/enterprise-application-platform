# DevOps Portfolio — Enterprise AWS Infrastructure

> Production-grade 3-tier infrastructure on AWS built with Terraform, Ansible, and Jenkins.
> Demonstrates: AWS architecture · Linux administration · IaC · Configuration management · CI/CD · Monitoring · Security hardening · Backup & recovery

---

## Architecture

```
Internet
    │  HTTPS 443
    ▼
Application Load Balancer  (Public Subnet 10.0.1.0/24)
    │  HTTP 80 → internal
    ▼
Nginx Reverse Proxy  ──────────────────────────────────────────────┐
                                                                    │
Private App Subnet (10.0.2.0/24)                                   │
    ├── App Server 1  (Ubuntu 22.04, Gitea)  ◄──────────────────── │
    ├── App Server 2  (Ubuntu 22.04, Gitea)  ◄──────────────────── │
    ├── RabbitMQ      (Ubuntu 22.04)                                │
    └── Memcached     (Ubuntu 22.04)                                │
                                                                    │
Private Tools Subnet (10.0.3.0/24)                                 │
    ├── Jenkins       (Ubuntu 22.04, CI/CD) ───────────────────────┘
    └── Bastion Host  (Ubuntu 22.04, SSH jump)

Private Data Subnet (10.0.4.0/24)
    └── MySQL 8       (CentOS 9, primary DB)
```

## Tech Stack

| Layer          | Technology                            |
|----------------|---------------------------------------|
| Cloud          | AWS (EC2, VPC, ALB, S3, CloudWatch)   |
| IaC            | Terraform 1.5+                        |
| Config Mgmt    | Ansible (roles, templates, handlers)  |
| CI/CD          | Jenkins (declarative pipeline)        |
| Application    | Gitea (self-hosted Git service)       |
| Database       | MySQL 8 on CentOS 9                   |
| Message Queue  | RabbitMQ 3.x                          |
| Cache          | Memcached                             |
| Reverse Proxy  | Nginx                                 |
| Monitoring     | CloudWatch Agent + Dashboards + Alarms|
| Notifications  | Slack (via SNS + Lambda)              |
| Secrets        | AWS SSM Parameter Store               |
| Backups        | S3 with lifecycle rules               |

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Ansible >= 2.14
- Python >= 3.10
- SSH key pair generated

### 1. Clone and configure
```bash
git clone https://github.com/YOUR_USERNAME/enterprise-application-platform.git
cd enterprise-application-platform
cp terraform/environments/production/terraform.tfvars.example \
   terraform/environments/production/terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Store secrets in SSM
```bash
make ssm-params
```

### 3. Generate SSH key
```bash
make keys
```

### 4. Deploy infrastructure
```bash
make tf-init
make tf-plan
make tf-apply
```

### 5. Configure servers
```bash
make export-ips
make ansible-deploy
```

### 6. Verify
```bash
make verify-ssh
curl https://your-domain.com/-/health
```

## Repository Structure

```
enterprise-application-platform/
├── terraform/
│   ├── modules/
│   │   ├── vpc/          # VPC, subnets, IGW, NAT, NACLs, Flow Logs
│   │   ├── compute/      # EC2 instances, AMI data sources
│   │   ├── security/     # All security groups, least-privilege rules
│   │   ├── alb/          # ALB, target group, listeners, Route 53
│   │   ├── iam/          # Instance profiles, roles, policies
│   │   ├── s3/           # Backup bucket, lifecycle rules
│   │   └── monitoring/   # CloudWatch dashboards, alarms, SNS, Lambda
│   └── environments/
│       └── production/   # main.tf, variables.tf, outputs.tf, tfvars
│
├── ansible/
│   ├── roles/
│   │   ├── common/       # OS hardening, SSH, sysctl, fail2ban, UFW
│   │   ├── nginx/        # Reverse proxy, security headers
│   │   ├── mysql/        # MySQL 8, hardening, user creation
│   │   ├── rabbitmq/     # RabbitMQ, vhost, user
│   │   ├── memcached/    # Memcached, binding, limits
│   │   ├── app/          # Gitea binary, systemd, config
│   │   ├── jenkins/      # Jenkins LTS, plugins, Nginx proxy
│   │   ├── monitoring/   # CloudWatch agent, log collection
│   │   └── backup/       # MySQL + app backup scripts, cron
│   ├── inventories/production/
│   ├── site.yml          # Master playbook
│   ├── ansible.cfg
│   └── requirements.yml  # Galaxy collections
│
├── jenkins/
│   ├── Jenkinsfile       # Declarative pipeline, rolling deploy
│   ├── jobs/             # Job DSL seed scripts
│   └── scripts/          # Credential setup reference
│
├── docs/
│   ├── architecture.md
│   ├── security.md
│   ├── monitoring.md
│   └── disaster-recovery.md
│
├── Makefile              # Convenient command shortcuts
└── .gitignore
```

## CI/CD Pipeline

```
GitHub push to main
       │
       ▼
  Jenkins webhook
       │
       ▼
  ┌─── Validate ───────────────────────────────┐
  │  Ansible syntax · Shell lint · TF fmt check │
  └────────────────────────────────────────────┘
       │
       ▼
  Download & verify Gitea binary (SHA256)
       │
       ▼
  Publish artifact to S3
       │
       ▼
  Pre-deploy SSH connectivity checks
       │
       ▼
  Deploy to app-01  →  Health check app-01
       │                       │
       │                  (fail → rollback app-01)
       ▼
  Deploy to app-02  →  Health check app-02
       │                       │
       │                  (fail → rollback app-02)
       ▼
  ALB smoke tests (3 endpoints)
       │
       ▼
  Record deployment to S3
       │
       ▼
  Slack notification ✅ / ❌
```

## Monitoring

CloudWatch dashboard at: `https://us-east-1.console.aws.amazon.com/cloudwatch`

Alarms configured:
- App server CPU > 80% for 10 min → Slack + email
- DB server CPU > 70% for 10 min → Slack + email
- ALB 5xx errors > 10/min → Slack + email
- ALB p95 latency > 2s for 3 min → Slack + email
- ALB healthy host count < 1 → Slack + email (critical)

## Backup & Recovery

| Schedule        | What                    | Destination              | Retention |
|-----------------|-------------------------|--------------------------|-----------|
| Daily 02:00 UTC | MySQL dump (incremental)| S3 db-backups/           | 7 days    |
| Sunday 03:00 UTC| MySQL full dump          | S3 db-backups/           | 30 days   |
| Daily 04:00 UTC | Backup integrity check   | CloudWatch metric        | —         |
| Daily 02:30 UTC | Gitea data dir           | S3 app-data/             | 7 days    |

Recovery steps documented in [docs/disaster-recovery.md](docs/disaster-recovery.md)

## Security Highlights

- No resources with public IP except Bastion and ALB
- All inter-service traffic controlled by security groups (least-privilege)
- Network ACLs as defence-in-depth second layer
- SSH: key-only auth, root login disabled, MaxAuthTries 3, fail2ban active
- All EBS volumes encrypted at rest (AES-256)
- All S3 objects encrypted at rest (KMS) + TLS enforced by bucket policy
- IAM roles — no long-lived access keys on any EC2 instance
- SSM Parameter Store for all secrets — no secrets in config files or environment variables
- VPC Flow Logs → CloudWatch (30-day retention)
- Jenkins in isolated tools subnet — not reachable from internet or app layer

## Cost Estimate

| Resource              | Monthly cost (approx.) |
|-----------------------|------------------------|
| 6× EC2 t3.small/medium| ~$25–35                |
| ALB                   | ~$16–20                |
| NAT Gateway           | ~$32                   |
| S3 (backups + logs)   | ~$2–5                  |
| CloudWatch            | ~$5–10                 |
| **Total**             | **~$80–100/month**     |

> Tip: Run `terraform destroy` at end of each day and `terraform apply` next morning to keep demo costs under $20 total for the week.

## Author

**Firdavs Samadov** — [GitHub](https://github.com/YOUR_USERNAME) · [LinkedIn](https://linkedin.com/in/YOUR_PROFILE)
