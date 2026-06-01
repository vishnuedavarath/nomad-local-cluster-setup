#!/bin/bash
set -euo pipefail

# Deploy CSI plugin jobs from nomad-jobs/csi/ using the Nomad CLI.
#
# Requires: NOMAD_ADDR and NOMAD_TOKEN set in environment.
#
# Usage:
#   ./scripts/deploy-csi-plugins.sh                      # Deploy all CSI plugins
#   ./scripts/deploy-csi-plugins.sh hostpath.nomad.hcl   # Deploy a specific plugin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CSI_DIR="$REPO_ROOT/nomad-jobs/csi"

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

  echo "==> Deploying CSI plugin: $name"
  if nomad job run "$jobfile"; then
    echo "    ✓ $name deployed"
  else
    echo "    ✗ $name FAILED" >&2
    return 1
  fi
}

# Determine which files to deploy
if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  FILES=()
  for f in "$CSI_DIR"/*.nomad "$CSI_DIR"/*.nomad.hcl; do
    [[ -f "$f" ]] && FILES+=("$f")
  done
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No CSI plugin job files found in $CSI_DIR"
  exit 0
fi

echo "Deploying ${#FILES[@]} CSI plugin(s) to $NOMAD_ADDR"
echo ""

FAILED=0
for file in "${FILES[@]}"; do
  if [[ "$file" != /* ]]; then
    file="$CSI_DIR/$file"
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
  echo "==> $FAILED CSI plugin(s) failed to deploy."
  exit 1
fi

echo "==> All CSI plugins deployed successfully."
echo ""
echo "Verify with: nomad plugin status"
