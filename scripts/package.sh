#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(sed -n "s/^our \\\$VERSION = '\\([^']*\\)';/\\1/p" "$ROOT_DIR/src/bin/help4-disk-usage-scan" | head -n 1)"
if [ -z "$VERSION" ]; then
  echo "Could not determine scanner version." >&2
  exit 2
fi
OUT_DIR="$ROOT_DIR/outputs"
PKG_DIR="$OUT_DIR/help4-disk-usage-${VERSION}"
TARBALL="$OUT_DIR/help4-disk-usage-${VERSION}.tar.gz"

rm -rf "$PKG_DIR" "$TARBALL"
mkdir -p "$PKG_DIR" "$OUT_DIR"

for path in README.md LICENSE NOTICE install.sh uninstall.sh src packaging integrations docs tests scripts; do
  cp -a "$ROOT_DIR/$path" "$PKG_DIR/"
done

find "$PKG_DIR" -type f -name '.DS_Store' -delete
find "$PKG_DIR" -type f -name '._*' -delete
COPYFILE_DISABLE=1 tar -C "$OUT_DIR" -czf "$TARBALL" "help4-disk-usage-${VERSION}"

echo "$TARBALL"
