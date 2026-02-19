#!/usr/bin/env bash
set -euo pipefail
COLLECTION_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Build and install collection from source so molecule uses latest code
echo "Building and installing collection from source..."
ansible-galaxy collection build "$COLLECTION_ROOT" --output-path /tmp --force
ansible-galaxy collection install /tmp/devlbo-secrets-*.tar.gz --force
rm -f /tmp/devlbo-secrets-*.tar.gz

for role_dir in "$COLLECTION_ROOT"/roles/*/; do
  role="$(basename "$role_dir")"
  if [[ -d "$role_dir/molecule/default" ]]; then
    echo "=== Testing role: $role ==="
    (cd "$role_dir" && molecule test -s default)
  fi
done
