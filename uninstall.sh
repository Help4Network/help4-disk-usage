#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = "--check" ] && [ "$#" -eq 1 ]; then
  exec perl "$ROOT_DIR/scripts/uninstall-preflight.pl"
fi
if [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--check]" >&2
  exit 2
fi
if [ "$(id -u)" -ne 0 ]; then
  echo "Uninstall must run as root on a cPanel & WHM server." >&2
  exit 1
fi

# Refuse unsafe managed paths before any backup, native hook or removal.
perl "$ROOT_DIR/scripts/uninstall-preflight.pl"
exec perl "$ROOT_DIR/scripts/uninstall-run.pl"
