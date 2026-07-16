#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/fixture/alice/backups" "$TMP_DIR/cache"
dd if=/dev/zero of="$TMP_DIR/fixture/alice/backups/site.tar.gz" bs=1024 count=1200 >/dev/null 2>&1

json="$("$ROOT_DIR/src/bin/help4-disk-usage-scan" \
  --fixture-root "$TMP_DIR/fixture" \
  --cache-dir "$TMP_DIR/cache" \
  --scope all \
  --large-mb 1 \
  --top 5)"

JSON_PAYLOAD="$json" perl -MJSON::PP=decode_json -e '
  my $d = decode_json($ENV{JSON_PAYLOAD});
  sub walk {
    my ($node) = @_;
    if (ref($node) eq "HASH") {
      die "absolute path key leaked in scanner JSON\n" if exists $node->{path};
      walk($_) for values %$node;
    } elsif (ref($node) eq "ARRAY") {
      walk($_) for @$node;
    }
  }
  walk($d);
  die "expected relative large file path\n" unless $d->{accounts}[0]{large_files}[0]{relative_path} eq "backups/site.tar.gz";
'

if [ "$(id -u)" -ne 0 ]; then
  if "$ROOT_DIR/src/bin/help4-disk-usage-scan" --scope account --account not_the_effective_user --home "$TMP_DIR/fixture/alice" >"$TMP_DIR/security.out" 2>&1; then
    echo "non-root scanner accepted a mismatched account/home" >&2
    exit 1
  fi
  grep -Eq "Non-root scans may only scan|Non-root scans must" "$TMP_DIR/security.out"
fi

echo "security boundary smoke test passed"
