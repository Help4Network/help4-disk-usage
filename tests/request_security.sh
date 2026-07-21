#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/cache/accounts" "$TMP_DIR/cache/locks" "$TMP_DIR/account-cache/accounts"
cat > "$TMP_DIR/config.json" <<JSON
{
  "display_name": "Storage Portal",
  "credit_prefix": "Built by",
  "release_url": "https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.6.tar.gz",
  "update_manifest_url": "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json",
  "scan_lock_dir": "$TMP_DIR/cache/locks",
  "whm_scan_max_seconds": 90,
  "cpanel_refreshes_per_hour": 3,
  "cpanel_min_interval_seconds": 300,
  "cpanel_scan_max_seconds": 60,
  "package_overrides": {}
}
JSON

whm_env=(
  "PERL5LIB=$ROOT_DIR/tests/lib"
  "HELP4_DU_CONFIG=$TMP_DIR/config.json"
  "HELP4_DU_CACHE_DIR=$TMP_DIR/cache"
  "REMOTE_USER=root"
  "QUERY_STRING="
)
whm_html="$(env "${whm_env[@]}" perl "$ROOT_DIR/src/whm/index.cgi")"
grep -q 'id="whm-left-navigation"' <<<"$whm_html"
grep -q 'id="whm-right-content"' <<<"$whm_html"
test "$(grep -o '<!doctype' <<<"$whm_html" | wc -l | tr -d ' ')" = "1"
test "$(grep -o '<html' <<<"$whm_html" | wc -l | tr -d ' ')" = "1"
whm_nonce="$(sed -n 's/.*name="action_nonce" value="\([0-9a-f]*\)".*/\1/p' <<<"$whm_html" | head -n 1)"
grep -Eq '^[0-9a-f]{64}$' <<<"$whm_nonce"

whm_get="$(env "${whm_env[@]}" QUERY_STRING=refresh=1 perl "$ROOT_DIR/src/whm/index.cgi")"
grep -q 'Request rejected' <<<"$whm_get"

whm_body="save_settings=1&action_nonce=$whm_nonce&display_name=Secured+Portal"
whm_post="$(printf '%s' "$whm_body" | env "${whm_env[@]}" REQUEST_METHOD=POST CONTENT_LENGTH="${#whm_body}" perl "$ROOT_DIR/src/whm/index.cgi")"
grep -q 'Settings saved' <<<"$whm_post"
grep -q '<h1>Secured Portal</h1>' <<<"$whm_post"

now="$(date +%s)"
cat > "$TMP_DIR/account-cache/rate.json" <<JSON
{"last_attempt":$now,"attempts":[$now]}
JSON
local_user="$(id -un)"
cat > "$TMP_DIR/account-cache/accounts/$local_user.json" <<JSON
{"user":"cross-account-user","large_files":[{"relative_path":"cross-account-secret"}]}
JSON
cpanel_env=(
  "PERL5LIB=$ROOT_DIR/tests/lib"
  "HELP4_DU_CONFIG=$TMP_DIR/config.json"
  "HELP4_DU_ACCOUNT_CACHE_DIR=$TMP_DIR/account-cache"
  "QUERY_STRING="
)
cpanel_html="$(env "${cpanel_env[@]}" perl "$ROOT_DIR/src/cpanel/index.live.pl")"
grep -q 'id="cpanel-main-navigation"' <<<"$cpanel_html"
grep -q 'id="cpanel-page-content"' <<<"$cpanel_html"
test "$(grep -o '<!doctype' <<<"$cpanel_html" | wc -l | tr -d ' ')" = "1"
test "$(grep -o '<html' <<<"$cpanel_html" | wc -l | tr -d ' ')" = "1"
if grep -q 'cross-account-secret' <<<"$cpanel_html"; then
  echo "cPanel rendered cache data belonging to another account." >&2
  exit 1
fi
cpanel_nonce="$(sed -n 's/.*name="action_nonce" value="\([0-9a-f]*\)".*/\1/p' <<<"$cpanel_html" | head -n 1)"
grep -Eq '^[0-9a-f]{64}$' <<<"$cpanel_nonce"

cpanel_rejected="$(env "${cpanel_env[@]}" REMOTE_USER=cross-account-user perl "$ROOT_DIR/src/cpanel/index.live.pl")"
grep -q '^Status: 403 Forbidden' <<<"$cpanel_rejected"
grep -q 'Account identity mismatch' <<<"$cpanel_rejected"
grep -q 'id="cpanel-main-navigation"' <<<"$cpanel_rejected"
if grep -q 'cross-account-secret' <<<"$cpanel_rejected"; then
  echo "cPanel rendered account data after an identity mismatch." >&2
  exit 1
fi

cpanel_get="$(env "${cpanel_env[@]}" QUERY_STRING=refresh=1 perl "$ROOT_DIR/src/cpanel/index.live.pl")"
grep -q 'Request rejected' <<<"$cpanel_get"

cpanel_body="refresh=1&action_nonce=$cpanel_nonce"
cpanel_post="$(printf '%s' "$cpanel_body" | env "${cpanel_env[@]}" REQUEST_METHOD=POST CONTENT_LENGTH="${#cpanel_body}" perl "$ROOT_DIR/src/cpanel/index.live.pl")"
grep -q 'Refresh throttled' <<<"$cpanel_post"

echo "request security smoke test passed"
