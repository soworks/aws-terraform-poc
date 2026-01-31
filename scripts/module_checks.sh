#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TF_DIRS=(
  "bootstrap"
  "components/network/vpc"
  "components/app"
  "modules/vpc"
  "modules/alb-ec2"
)

for dir in "${TF_DIRS[@]}"; do
  path="${ROOT_DIR}/${dir}"
  if [[ ! -d "${path}" ]]; then
    continue
  fi

  echo "==> terraform checks: ${dir}"
  if ! terraform -chdir="${path}" fmt -check -diff; then
    echo "ERROR: terraform fmt failed in ${dir}"
    exit 1
  fi

  if [[ -d "${path}/.terraform" ]]; then
    if ! terraform -chdir="${path}" validate; then
      echo "ERROR: terraform validate failed in ${dir}"
      exit 1
    fi
  else
    echo "Skipping validate (no .terraform). Run terraform init to enable."
  fi
done
