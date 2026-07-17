#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="$ROOT_DIR/integrations/whmcs/modules/addons/help4_disk_usage"
VERSION="$(sed -n "s/^our \\\$VERSION = '\\([^']*\\)';/\\1/p" "$ROOT_DIR/src/bin/help4-disk-usage-scan" | head -n 1)"
MODULE_VERSION="$(sed -n "s/^const H4DU_VERSION = '\([^']*\)';/\1/p" "$MODULE_DIR/help4_disk_usage.php" | head -n 1)"

if [ -z "$VERSION" ] || [ "$VERSION" != "$MODULE_VERSION" ]; then
  echo "Scanner and WHMCS addon versions do not match." >&2
  exit 2
fi

command -v zip >/dev/null 2>&1 || {
  echo "zip is required to build the WHMCS addon package." >&2
  exit 3
}

OUT_DIR="$ROOT_DIR/outputs"
ZIP_FILE="$OUT_DIR/help4-disk-usage-whmcs-${VERSION}.zip"
CHECKSUM_FILE="$ZIP_FILE.sha256"
mkdir -p "$OUT_DIR"
STAGE_DIR="$(mktemp -d "$OUT_DIR/.help4-disk-usage-whmcs.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

rm -f "$ZIP_FILE" "$CHECKSUM_FILE"
mkdir -p "$STAGE_DIR/help4_disk_usage"
cp -a "$MODULE_DIR/." "$STAGE_DIR/help4_disk_usage/"
cp "$ROOT_DIR/docs/whmcs-integration.md" "$STAGE_DIR/help4_disk_usage/README.md"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/help4_disk_usage/LICENSE"
printf '%s\n' "$VERSION" > "$STAGE_DIR/help4_disk_usage/VERSION"
find "$STAGE_DIR" -type f \( -name '._*' -o -name '.DS_Store' \) -delete

(
  cd "$STAGE_DIR"
  zip -X -qr "$ZIP_FILE" help4_disk_usage
)

if command -v sha256sum >/dev/null 2>&1; then
  package_sha256="$(sha256sum "$ZIP_FILE" | awk '{print $1}')"
else
  package_sha256="$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')"
fi
printf '%s  %s\n' "$package_sha256" "$(basename "$ZIP_FILE")" > "$CHECKSUM_FILE"

echo "$ZIP_FILE"
echo "$CHECKSUM_FILE"
