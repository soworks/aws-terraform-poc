# aws-terraform-poc

Terraform POC that creates a VPC, ALB, and an application server running Nginx
with a fun landing page (and optional uWSGI app).

## Structure

- `bootstrap/` creates the S3 state bucket.
- `components/network/vpc/` provisions the VPC and public subnets.
- `components/app/` provisions the ALB + EC2 via the `modules/alb-ec2` module.
- `modules/` contains reusable Terraform modules.
- `scripts/` includes CI helper scripts.

## Prereqs

- Terraform >= 1.6
- AWS credentials with permissions to create VPC/EC2/ELB/S3/IAM
- `terraform-docs`, `pre-commit`, `checkov` installed for local checks

## Bootstrap state backend

1. Initialize and apply the bootstrap stack:
   ```bash
   cd bootstrap
   terraform init
   terraform apply
   ```
2. Note the output for the state bucket.

## Deploy VPC

1. Configure the backend for the VPC component:
   ```bash
   cd components/network/vpc
   terraform init -backend-config="bucket=<state-bucket>" \
     -backend-config="region=us-east-1"
   ```
2. Apply:
   ```bash
   terraform apply
   ```

## Deploy ALB + app server

1. Configure backend:
   ```bash
   cd components/app
   terraform init -backend-config="bucket=<state-bucket>" \
     -backend-config="region=us-east-1"
   ```
2. Apply:
   ```bash
   terraform apply
   ```
3. Open the `alb_dns_name` output in a browser.

## Local checks

```bash
pre-commit install
pre-commit run --all-files
```

## CI

GitHub Actions runs:
- `terraform fmt` and `terraform validate`
- `terraform-docs` with README diff check
- `checkov` scans
- `terraform plan` on PRs (via GitHub OIDC)

## GitHub Actions (OIDC)

The bootstrap stack now creates a GitHub Actions OIDC provider and IAM role for
CI plans.

1. Apply the bootstrap stack:
   ```bash
   cd bootstrap
   terraform init
   terraform apply
   ```
2. Add the output `github_actions_role_arn` to GitHub repo secrets:
   - `AWS_ROLE_ARN`
