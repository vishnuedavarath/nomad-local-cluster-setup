#!/bin/bash
set -euo pipefail

# Deploy Nomad jobs from the nomad-jobs/ directory using the CLI.
#
# Requires: NOMAD_ADDR and NOMAD_TOKEN set in environment.
#
# Usage:
#   ./scripts/deploy-jobs.sh                    # Deploy all .nomad.hcl and .nomad files
#   ./scripts/deploy-jobs.sh nginx.nomad        # Deploy a specific job
#   ./scripts/deploy-jobs.sh foo.nomad.hcl bar.nomad.hcl  # Deploy multiple jobs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JOBS_DIR="$REPO_ROOT/nomad-jobs"

if [[ -z "${NOMAD_ADDR:-}" ]]; then
  echo "ERROR: NOMAD_ADDR is not set. Source your shell env or export it manually."
  exit 1
fi

if [[ -z "${NOMAD_TOKEN:-}" ]]; then
  echo "WARNING: NOMAD_TOKEN is not set. Jobs may fail if ACL is enabled."
fi

deploy_job() {
  local jobfile="$1"
  local name
  name="$(basename "$jobfile")"

  echo "==> Deploying: $name"
  if nomad job run "$jobfile"; then
    echo "    ✓ $name deployed"
  else
    echo "    ✗ $name FAILED" >&2
    return 1
  fi
}

# Determine which files to deploy
if [[ $# -gt 0 ]]; then
  # Deploy specified files
  FILES=("$@")
else
  # Deploy all job files (skip .tftpl templates — those need variable substitution)
  FILES=()
  for f in "$JOBS_DIR"/*.nomad "$JOBS_DIR"/*.nomad.hcl; do
    [[ -f "$f" ]] && FILES+=("$f")
  done
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No job files found in $JOBS_DIR"
  exit 0
fi

echo "Deploying ${#FILES[@]} job(s) to $NOMAD_ADDR"
echo ""

FAILED=0
for file in "${FILES[@]}"; do
  # Resolve relative paths against JOBS_DIR
  if [[ "$file" != /* ]]; then
    file="$JOBS_DIR/$file"
  fi

  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  deploy_job "$file" || FAILED=$((FAILED + 1))
  echo ""
done

if [[ $FAILED -gt 0 ]]; then
  echo "==> $FAILED job(s) failed to deploy."
  exit 1
fi

echo "==> All jobs deployed successfully."
