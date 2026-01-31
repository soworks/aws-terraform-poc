# Internal Notes

## CI checks (why they exist)

### `ci-checks` job
- `scripts/module_checks.sh`: runs `terraform fmt -check -diff` to enforce
  formatting and `terraform validate` when a module has already been initialized.
  This keeps CI fast and avoids auto-initializing remote backends.
- Checkov scan: static analysis for Terraform security and compliance issues.
  The config lives in `.checkov.yaml` to keep the rules consistent across local
  runs and CI.

### `terraform-plan` job (PRs only)
- Uses GitHub OIDC to assume an AWS role (no static credentials in CI).
- Runs `terraform plan` for the VPC and app components.
- Posts a sticky PR comment with the plan output so reviewers can see infra
  changes without opening logs.

### `pr-agent` workflow
- Posts AI-generated PR description, review, and code suggestions.
- Runs only on new or reopened PRs to reduce noise and cost.

## VPC module: dynamic subnet lookup

The VPC module derives AZs and subnet CIDRs dynamically:
- `data.aws_availability_zones.available` lists the AZs for the current region.
- `local.az_count` is the max of public/private subnet counts, ensuring enough
  AZs for both tiers.
- `local.azs` slices the available AZ list to the required count.
- `cidrsubnet` is used to deterministically derive subnet CIDRs from the VPC
  CIDR, splitting public first and then private ranges.
- A lifecycle precondition in `aws_vpc.this` validates that the region has
  enough AZs for the requested subnet counts.
