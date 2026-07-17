#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v unzip >/dev/null 2>&1

mapfile_output="$($ROOT_DIR/scripts/package-whmcs.sh)"
ZIP_FILE="$(printf '%s\n' "$mapfile_output" | sed -n '1p')"
CHECKSUM_FILE="$(printf '%s\n' "$mapfile_output" | sed -n '2p')"
test -s "$ZIP_FILE"
test -s "$CHECKSUM_FILE"

entries="$(unzip -Z1 "$ZIP_FILE")"
printf '%s\n' "$entries" | grep -qx 'help4_disk_usage/help4_disk_usage.php'
printf '%s\n' "$entries" | grep -qx 'help4_disk_usage/hooks.php'
printf '%s\n' "$entries" | grep -qx 'help4_disk_usage/templates/clientarea.tpl'
printf '%s\n' "$entries" | grep -qx 'help4_disk_usage/README.md'
printf '%s\n' "$entries" | grep -qx 'help4_disk_usage/LICENSE'
printf '%s\n' "$entries" | grep -qx 'help4_disk_usage/VERSION'

if printf '%s\n' "$entries" | grep -Eq '(^/|(^|/)\.\.(/|$)|(^|/)\._|(^|/)\.DS_Store$)'; then
  echo "WHMCS package contains an unsafe or private path." >&2
  exit 1
fi

VERSION="$(unzip -p "$ZIP_FILE" help4_disk_usage/VERSION | tr -d '\r\n')"
unzip -p "$ZIP_FILE" help4_disk_usage/help4_disk_usage.php \
  | grep -q "const H4DU_VERSION = '$VERSION';"
unzip -p "$ZIP_FILE" help4_disk_usage/README.md | grep -q '^## Install$'
unzip -p "$ZIP_FILE" help4_disk_usage/README.md | grep -q '^## Upgrade$'
unzip -p "$ZIP_FILE" help4_disk_usage/README.md | grep -q '^## Remove the Addon$'

expected_sha256="$(awk 'NR == 1 {print $1}' "$CHECKSUM_FILE")"
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum "$ZIP_FILE" | awk '{print $1}')"
else
  actual_sha256="$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')"
fi
test "$actual_sha256" = "$expected_sha256"

echo "WHMCS package test passed"
