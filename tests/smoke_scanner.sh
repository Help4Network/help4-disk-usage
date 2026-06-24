#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/fixture/alice/public_html/wp-content/cache/page" \
  "$TMP_DIR/fixture/alice/logs" \
  "$TMP_DIR/fixture/alice/backups" \
  "$TMP_DIR/fixture/bob/tmp/sessions" \
  "$TMP_DIR/cache"

dd if=/dev/zero of="$TMP_DIR/fixture/alice/backups/site.sql" bs=1024 count=1400 >/dev/null 2>&1
dd if=/dev/zero of="$TMP_DIR/fixture/alice/public_html/wp-content/cache/page/a.cache" bs=1024 count=16 >/dev/null 2>&1
dd if=/dev/zero of="$TMP_DIR/fixture/alice/logs/error.log" bs=1024 count=8 >/dev/null 2>&1
for i in $(seq 1 40); do printf 'x' > "$TMP_DIR/fixture/bob/tmp/sessions/sess_$i"; done

json="$("$ROOT_DIR/src/bin/help4-disk-usage-scan" \
  --fixture-root "$TMP_DIR/fixture" \
  --cache-dir "$TMP_DIR/cache" \
  --scope all \
  --large-mb 1 \
  --top 5 \
  --write-cache)"

JSON_PAYLOAD="$json" perl -MJSON::PP=decode_json -e '
  my $d = decode_json($ENV{JSON_PAYLOAD});
  die "expected two accounts\n" unless $d->{account_count} == 2;
  my ($alice) = grep { $_->{user} eq "alice" } @{$d->{accounts}};
  die "alice missing\n" unless $alice;
  die "large file missing\n" unless @{$alice->{large_files}};
  my %cats = map { $_->{category} => 1 } @{$alice->{category_hotspots}};
  die "backup category missing\n" unless $cats{backups};
  die "cache category missing\n" unless $cats{cache};
'

test -s "$TMP_DIR/cache/accounts/alice.json"
test -s "$TMP_DIR/cache/accounts/bob.json"

account_json="$("$ROOT_DIR/src/bin/help4-disk-usage-scan" \
  --fixture-root "$TMP_DIR/fixture" \
  --cache-dir "$TMP_DIR/cache" \
  --scope account \
  --account alice \
  --large-mb 1 \
  --top 5)"

JSON_PAYLOAD="$account_json" perl -MJSON::PP=decode_json -e '
  my $d = decode_json($ENV{JSON_PAYLOAD});
  die "account scope leaked other users\n" unless $d->{account_count} == 1 && $d->{accounts}[0]{user} eq "alice";
'

echo "scanner smoke test passed"
