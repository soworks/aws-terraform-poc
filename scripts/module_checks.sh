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
  terraform -chdir="${path}" fmt -check -diff
  if [[ -d "${path}/.terraform" ]]; then
    terraform -chdir="${path}" validate
  else
    echo "Skipping validate (no .terraform). Run terraform init to enable."
  fi
done
