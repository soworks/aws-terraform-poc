#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

terraform-docs -c "${ROOT_DIR}/.terraform-docs.yml" "${ROOT_DIR}/modules/vpc"
terraform-docs -c "${ROOT_DIR}/.terraform-docs.yml" "${ROOT_DIR}/modules/alb-ec2"
