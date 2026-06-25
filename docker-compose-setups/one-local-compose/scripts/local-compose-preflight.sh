#!/usr/bin/env bash
# Validate AWS credentials before starting one-local.docker-compose.yml.
# Does not print or store secret values.

set -euo pipefail

readonly PROFILES=(
  "dev"
  "741448925364_AdministratorAccess"
)

readonly SSO_LOGIN_COMMANDS=(
  "aws sso login --profile dev"
  "aws sso login --profile 741448925364_AdministratorAccess"
)

print_usage() {
  cat <<'EOF'
Usage: ./local-compose-preflight.sh

Validates required AWS profiles before docker compose up.
Exits 0 when all profiles are valid; exits 1 with login instructions otherwise.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed or not on PATH."
  echo "Install the AWS CLI, then re-run this script."
  exit 1
fi

failed=0

for i in "${!PROFILES[@]}"; do
  profile="${PROFILES[$i]}"
  login_cmd="${SSO_LOGIN_COMMANDS[$i]}"

  echo "Checking AWS profile: ${profile}"

  if aws sts get-caller-identity --profile "${profile}" >/dev/null 2>&1; then
    echo "  OK: profile '${profile}' is valid."
    continue
  fi

  echo "  FAIL: profile '${profile}' is invalid or expired."
  echo "  Run: ${login_cmd}"
  failed=1
done

if [[ "${failed}" -ne 0 ]]; then
  echo
  echo "Preflight failed. Refresh AWS credentials, then run:"
  echo "  cd one-local-compose"
  echo "  make preflight"
  echo "  make up-local"
  exit 1
fi

echo
echo "Preflight passed. AWS profiles are valid."
exit 0
