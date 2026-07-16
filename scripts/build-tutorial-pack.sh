#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(sed -n "s/^our \\\$VERSION = '\\([^']*\\)';/\\1/p" "$ROOT_DIR/src/bin/help4-disk-usage-scan" | head -n 1)"
NODE_BIN="${NODE_BIN:-node}"
OUT_DIR="$ROOT_DIR/outputs"
SCREENSHOT_DIR="$OUT_DIR/screenshots"
PACK_NAME="help4-disk-usage-v${VERSION}-tutorial-pack"
PACK_DIR="$OUT_DIR/$PACK_NAME"
ZIP_FILE="$OUT_DIR/$PACK_NAME.zip"

test -n "$VERSION"
command -v "$NODE_BIN" >/dev/null 2>&1 || test -x "$NODE_BIN"
command -v zip >/dev/null 2>&1
command -v rg >/dev/null 2>&1

rm -rf "$SCREENSHOT_DIR" "$PACK_DIR" "$ZIP_FILE"
mkdir -p "$PACK_DIR/screenshots" "$PACK_DIR/docs"

"$NODE_BIN" "$ROOT_DIR/scripts/render-marketing-screenshots.js"
cp -a "$SCREENSHOT_DIR/." "$PACK_DIR/screenshots/"

cp "$ROOT_DIR/docs/marketing/tutorial-pack-readme.md" "$PACK_DIR/README.md"
cp "$ROOT_DIR/README.md" "$PACK_DIR/docs/project-readme.md"
cp "$ROOT_DIR/docs/whmcs-integration.md" "$PACK_DIR/docs/whmcs-integration.md"
cp "$ROOT_DIR/docs/security-review.md" "$PACK_DIR/docs/security-notes.md"
cp "$ROOT_DIR/docs/usage-guide.md" "$PACK_DIR/docs/usage-guide.md"
cp "$ROOT_DIR/docs/rollout.md" "$PACK_DIR/docs/rollout.md"
cp "$ROOT_DIR/docs/marketing/marketing-brief.md" "$PACK_DIR/docs/marketing-brief.md"
cp "$ROOT_DIR/CHANGELOG.md" "$PACK_DIR/CHANGELOG.md"
cp "$ROOT_DIR/LICENSE" "$PACK_DIR/LICENSE"

# Public tutorial material uses generic node labels even where engineering docs name rollout targets.
LC_ALL=C LANG=C find "$PACK_DIR" -type f -name '*.md' -exec perl -pi -e '
  s/Genie/Validation Node A/g;
  s/gohoster/Future Node B/g;
  s/dolce01/Future Node C/g;
' {} +

if rg -i -n 'randomhostingservices|\bgenie\b|\bgohoster\b|\bdolce01\b' "$PACK_DIR"; then
  echo "Tutorial pack contains a forbidden live identifier." >&2
  exit 1
fi
if [ -n "${H4DU_TUTORIAL_DENYLIST_REGEX:-}" ] && rg -i -n "$H4DU_TUTORIAL_DENYLIST_REGEX" "$PACK_DIR"; then
  echo "Tutorial pack matched the operator-provided privacy denylist." >&2
  exit 1
fi

(
  cd "$OUT_DIR"
  zip -qr "$ZIP_FILE" "$PACK_NAME"
)

echo "$ZIP_FILE"
