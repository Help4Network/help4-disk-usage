#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/cache/accounts" "$TMP_DIR/cache/locks" "$TMP_DIR/home"
cat > "$TMP_DIR/config.json" <<'JSON'
{
  "display_name": "Storage Portal",
  "credit_prefix": "Built by",
  "release_url": "https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.3.tar.gz",
  "update_manifest_url": "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json",
  "whm_scan_max_seconds": 90,
  "cpanel_refreshes_per_hour": 3,
  "cpanel_min_interval_seconds": 300,
  "cpanel_scan_max_seconds": 60,
  "package_overrides": {}
}
JSON

whm_html="$(HELP4_DU_CONFIG="$TMP_DIR/config.json" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" REMOTE_USER=root QUERY_STRING= "$ROOT_DIR/src/whm/index.cgi")"
grep -q '<h1>Storage Portal</h1>' <<<"$whm_html"
grep -q 'href="https://help4network.com/"' <<<"$whm_html"
grep -q 'Help4 Network' <<<"$whm_html"
grep -q 'Update manifest URL' <<<"$whm_html"

cpanel_html="$(HELP4_DU_CONFIG="$TMP_DIR/config.json" HELP4_DU_ACCOUNT_CACHE_DIR="$TMP_DIR/account-cache" QUERY_STRING= "$ROOT_DIR/src/cpanel/index.live.pl")"
grep -q '<h1>Storage Portal</h1>' <<<"$cpanel_html"
grep -q 'href="https://help4network.com/"' <<<"$cpanel_html"
grep -q 'Help4 Network' <<<"$cpanel_html"

json="$("$ROOT_DIR/src/bin/help4-disk-usage-scan" --fixture-root "$TMP_DIR/home" --cache-dir "$TMP_DIR/cache" --scope all --max-seconds 1 --top 1)"
JSON_PAYLOAD="$json" perl -MJSON::PP=decode_json -e '
  my $d = decode_json($ENV{JSON_PAYLOAD});
  die "missing report credit text\n" unless ($d->{credit}{text} || "") eq "Built by Help4 Network";
  die "missing report credit url\n" unless ($d->{credit}{url} || "") eq "https://help4network.com/";
'

"$ROOT_DIR/src/bin/help4-disk-usage-update" --help | grep -q -- '--manifest-url'

scanner_version="$("$ROOT_DIR/src/bin/help4-disk-usage-scan" --help | sed -n 's/^Help4 Disk Usage scanner v//p' | head -n 1)"
manifest_version="$(perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); print $d->{version};' "$ROOT_DIR/update.json")"
if [ "${HELP4_DU_PREPUBLICATION_MANIFEST:-0}" != "1" ]; then
  test "$scanner_version" = "$manifest_version"
fi
manifest_sha="$(perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); print $d->{sha256};' "$ROOT_DIR/update.json")"
grep -Eq '^[0-9a-f]{64}$' <<<"$manifest_sha"

grep -q 'update manifest must provide sha256' "$ROOT_DIR/src/bin/help4-disk-usage-update"
grep -q 'SSH2_FINGERPRINT_SHA256' "$ROOT_DIR/integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php"
grep -q 'Remote command output exceeded the 16 MiB safety limit' "$ROOT_DIR/integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php"

echo "branding/update contract smoke test passed"
