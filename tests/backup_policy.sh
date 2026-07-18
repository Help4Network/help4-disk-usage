#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for script in install.sh uninstall.sh; do
  path="$ROOT_DIR/$script"
  grep -Fq 'BACKUP_ROOT="${HELP4_DU_BACKUP_DIR:-}"' "$path"
  grep -Fq 'if [ -n "$BACKUP_ROOT" ]; then' "$path"
done

if grep -Eq '/root/help4-disk-usage-(install|uninstall)-backups' \
  "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh"; then
  echo "Install scripts must not define a default filesystem backup path." >&2
  exit 1
fi

if grep -Eq 'BACKUP_DIR=/var/backups/help4-disk-usage|Back up the current module directory' \
  "$ROOT_DIR/README.md" "$ROOT_DIR/docs/whmcs-integration.md"; then
  echo "Documentation must use immutable release packages as the default rollback source." >&2
  exit 1
fi

echo "Backup policy test passed"
