#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export HELP4_DU_TEST_ROOT="$TMP_DIR"
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/app/bin" "$TMP_DIR/cache" "$TMP_DIR/package/src/bin"

# Run the production updater against isolated commands and paths, without root or network.
sed -e "s#/usr/local/cpanel/3rdparty/help4-disk-usage#$TMP_DIR/app#g" \
    -e "s#/root/help4-disk-usage-update\.#$TMP_DIR/update.#g" \
    "$ROOT_DIR/src/bin/help4-disk-usage-update" > "$TMP_DIR/updater"
cat > "$TMP_DIR/bin/id" <<'SH'
#!/usr/bin/env bash
echo 0
SH
cat > "$TMP_DIR/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
destination=''
url=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then shift; destination="$1"; fi
  case "$1" in https://*) url="$1";; esac
  shift
done
printf '%s\n' "$url" >> "$HELP4_DU_TEST_ROOT/requests"
case "$url" in
  */update.json) cp "$HELP4_DU_TEST_ROOT/manifest.json" "$destination";;
  */package.tar.gz) cp "$HELP4_DU_TEST_ROOT/package.tar.gz" "$destination";;
  *) exit 22;;
esac
SH
cat > "$TMP_DIR/app/bin/help4-disk-usage-scan" <<'SH'
#!/usr/bin/env bash
echo 'Help4 Disk Usage scanner v0.0.1'
SH
cp "$ROOT_DIR/src/bin/help4-disk-usage-scan" "$TMP_DIR/package/src/bin/help4-disk-usage-scan"
cat > "$TMP_DIR/package/install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n%s\n' "$HELP4_DU_UPDATE_MANIFEST_URL" "$HELP4_DU_RELEASE_URL" > "$HELP4_DU_TEST_ROOT/installed-channel"
if [ "${HELP4_DU_TEST_FAIL_READBACK:-0}" = 1 ]; then exit 0; fi
version="$(sed -n "s/^our \\\$VERSION = '\\([^']*\\)';/\\1/p" "$(dirname "$0")/src/bin/help4-disk-usage-scan")"
printf '#!/usr/bin/env bash\necho "Help4 Disk Usage scanner v%s"\n' "$version" > "$HELP4_DU_TEST_ROOT/app/bin/help4-disk-usage-scan"
printf '{"version":"%s"}\n' "$version" > "$HELP4_DU_TEST_ROOT/cache/install.json"
SH
chmod 0755 "$TMP_DIR/bin/"* "$TMP_DIR/app/bin/"* "$TMP_DIR/package/install.sh"
tar -czf "$TMP_DIR/package.tar.gz" -C "$TMP_DIR" package
sha="$(shasum -a 256 "$TMP_DIR/package.tar.gz" | awk '{print $1}')"
version="$("$ROOT_DIR/src/bin/help4-disk-usage-scan" --help | sed -n 's/^Help4 Disk Usage scanner v//p')"
printf '{"version":"%s","package_url":"https://releases.example.test/package.tar.gz","sha256":"%s"}\n' "$version" "$sha" > "$TMP_DIR/manifest.json"
printf '{"update_manifest_url":"https://current.example.test/update.json"}\n' > "$TMP_DIR/cache/config.json"
printf '{"update_manifest_url":"https://old.example.test/update.json"}\n' > "$TMP_DIR/cache/install.json"

env PATH="$TMP_DIR/bin:$PATH" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" \
  bash "$TMP_DIR/updater" --apply > "$TMP_DIR/result.json"
grep -qx 'https://current.example.test/update.json' "$TMP_DIR/installed-channel"
grep -qx 'https://releases.example.test/package.tar.gz' "$TMP_DIR/installed-channel"
perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); die "apply failed" unless $d->{ok} && $d->{changed};' "$TMP_DIR/result.json"
env PATH="$TMP_DIR/bin:$PATH" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" \
  bash "$TMP_DIR/updater" --check --manifest-url https://explicit.example.test/update.json > "$TMP_DIR/result.json"
perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); die "CLI channel precedence lost" unless $d->{manifest_url} eq "https://explicit.example.test/update.json";' "$TMP_DIR/result.json"
# A copied scanner is not proof that registration and the rest of install completed.
printf '{"version":"0.0.1"}\n' > "$TMP_DIR/cache/install.json"
env PATH="$TMP_DIR/bin:$PATH" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" \
  bash "$TMP_DIR/updater" --check > "$TMP_DIR/result.json"
perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); die "partial installation reported current" unless $d->{installation_incomplete} && $d->{update_available};' "$TMP_DIR/result.json"
env PATH="$TMP_DIR/bin:$PATH" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" \
  bash "$TMP_DIR/updater" --apply > "$TMP_DIR/result.json"
perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); die "partial install not repaired without force" unless $d->{ok} && $d->{changed} && !$d->{installation_incomplete};' "$TMP_DIR/result.json"
printf '{"version":"0.0.1"}\n' > "$TMP_DIR/cache/install.json"
if env PATH="$TMP_DIR/bin:$PATH" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" HELP4_DU_TEST_FAIL_READBACK=1 \
    bash "$TMP_DIR/updater" --apply > "$TMP_DIR/result.json"; then
  echo 'Inconsistent post-install readback was accepted' >&2
  exit 1
fi
grep -q 'completed-install version readback is inconsistent' "$TMP_DIR/result.json"
printf '{"version":"%s","package_url":"https://releases.example.test/package.tar.gz","sha256":"%064d"}\n' "$version" 0 > "$TMP_DIR/manifest.json"
if env PATH="$TMP_DIR/bin:$PATH" HELP4_DU_CACHE_DIR="$TMP_DIR/cache" \
    bash "$TMP_DIR/updater" --apply --force > "$TMP_DIR/result.json"; then
  echo 'Incorrect release checksum was accepted' >&2
  exit 1
fi
grep -q 'sha256 does not match' "$TMP_DIR/result.json"
echo 'Updater channel, checksum, and partial-install repair tests passed'
