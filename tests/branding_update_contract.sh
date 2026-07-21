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
  "release_url": "https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.6.tar.gz",
  "update_manifest_url": "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json",
  "whm_scan_max_seconds": 90,
  "cpanel_refreshes_per_hour": 3,
  "cpanel_min_interval_seconds": 300,
  "cpanel_scan_max_seconds": 60,
  "package_overrides": {}
}
JSON

whm_html="$(PERL5LIB="$ROOT_DIR/tests/lib" HELP4_DU_CONFIG="$TMP_DIR/config.json" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" REMOTE_USER=root QUERY_STRING= perl "$ROOT_DIR/src/whm/index.cgi")"
grep -q 'id="whm-left-navigation"' <<<"$whm_html"
grep -q 'id="whm-right-content"' <<<"$whm_html"
grep -q '<h1>Storage Portal</h1>' <<<"$whm_html"
grep -q 'href="https://help4network.com/"' <<<"$whm_html"
grep -q 'Help4 Network' <<<"$whm_html"
grep -q 'Update manifest URL' <<<"$whm_html"
grep -q "WRAPPER 'master_templates/master.tmpl'" "$ROOT_DIR/src/whm/templates/index.tmpl"
grep -q 'help4-disk-usage-whm.css' "$ROOT_DIR/src/whm/templates/index.tmpl"
if grep -Eq '^[[:space:]]*(body|html|h1|h2|table|th|td)[[:space:],{]' "$ROOT_DIR/src/static/help4-disk-usage-whm.css"; then
  echo "Shared stylesheet contains an unscoped global selector." >&2
  exit 1
fi

cpanel_html="$(PERL5LIB="$ROOT_DIR/tests/lib" HELP4_DU_CONFIG="$TMP_DIR/config.json" HELP4_DU_ACCOUNT_CACHE_DIR="$TMP_DIR/account-cache" QUERY_STRING= perl "$ROOT_DIR/src/cpanel/index.live.pl")"
grep -q 'id="cpanel-main-navigation"' <<<"$cpanel_html"
grep -q 'id="cpanel-page-content"' <<<"$cpanel_html"
test "$(grep -o '<!doctype' <<<"$cpanel_html" | wc -l | tr -d ' ')" = "1"
test "$(grep -o '<html' <<<"$cpanel_html" | wc -l | tr -d ' ')" = "1"
test "$(grep -o '<h1' <<<"$cpanel_html" | wc -l | tr -d ' ')" = "1"
grep -q '<h1>Storage Portal</h1>' <<<"$cpanel_html"
grep -q 'href="https://help4network.com/"' <<<"$cpanel_html"
grep -q 'Help4 Network' <<<"$cpanel_html"
cpanel_group="$(perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); print $d->[0]{group_id} || "";' "$ROOT_DIR/packaging/install.json")"
test "$cpanel_group" = "files"
grep -q 'https://help4network.com/assets/img/logo.png' "$ROOT_DIR/src/static/help4-disk-usage.svg"
grep -q 'data:image/png;base64,' "$ROOT_DIR/src/static/help4-disk-usage.svg"
file "$ROOT_DIR/src/static/help4-disk-usage.png" | grep -q 'PNG image data, 48 x 48, 8-bit/color RGBA'
head -n 1 "$ROOT_DIR/src/cpanel/index.live.pl" | grep -qx '#!/usr/local/cpanel/3rdparty/bin/perl'
grep -q 'Cpanel::LiveAPI->new' "$ROOT_DIR/src/cpanel/index.live.pl"
grep -q '\$cpanel->header' "$ROOT_DIR/src/cpanel/index.live.pl"
grep -q '\$cpanel->footer' "$ROOT_DIR/src/cpanel/index.live.pl"
grep -q '\$cpanel->end' "$ROOT_DIR/src/cpanel/index.live.pl"
if grep -Eq '<!doctype|<html|<body' "$ROOT_DIR/src/cpanel/index.live.pl"; then
  echo "cPanel plugin contains a standalone document outside the LiveAPI shell." >&2
  exit 1
fi

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
