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
mkdir -p "$OUT_DIR"

git -C "$ROOT_DIR" archive --format=tar --prefix="help4-disk-usage-${VERSION}/" HEAD \
  | gzip -c > "$TARBALL"

mkdir -p "$PKG_DIR"
tar -xzf "$TARBALL" -C "$OUT_DIR"

echo "$TARBALL"
