#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Install must run as root on a cPanel & WHM server." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="/root/help4-disk-usage-install-backups/${STAMP}"
VERSION="$(sed -n "s/^our \\\$VERSION = '\\([^']*\\)';/\\1/p" "$ROOT_DIR/src/bin/help4-disk-usage-scan" | head -n 1)"
RELEASE_URL="${HELP4_DU_RELEASE_URL:-https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.4.tar.gz}"
UPDATE_MANIFEST_URL="${HELP4_DU_UPDATE_MANIFEST_URL:-https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json}"

APP_DIR="/usr/local/cpanel/3rdparty/help4-disk-usage"
WHM_CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage"
WHM_TEMPLATE_DIR="/usr/local/cpanel/whostmgr/docroot/templates/help4_disk_usage"
WHM_STATIC_DIR="/usr/local/cpanel/whostmgr/docroot/help4-disk-usage"
WHM_ICON_DIR="/usr/local/cpanel/whostmgr/docroot/addon_plugins"
CPANEL_DIR="/usr/local/cpanel/base/frontend/jupiter/help4_disk_usage"
CACHE_DIR="/var/cpanel/help4-disk-usage"
LOCK_DIR="$CACHE_DIR/locks"
CONFIG_FILE="$CACHE_DIR/config.json"
INSTALL_META="$CACHE_DIR/install.json"
APP_CONF="/var/cpanel/apps/help4_disk_usage.conf"
CRON_FILE="/etc/cron.d/help4-disk-usage"

for required in /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/scripts/install_plugin; do
  if [ ! -x "$required" ]; then
    echo "Missing required cPanel command: $required" >&2
    exit 2
  fi
done

mkdir -p "$BACKUP_DIR"
for path in "$APP_DIR" "$WHM_CGI_DIR" "$WHM_TEMPLATE_DIR" "$WHM_STATIC_DIR" "$CPANEL_DIR" "$CONFIG_FILE" "$APP_CONF" "$CRON_FILE"; do
  if [ -e "$path" ]; then
    backup_name="$(printf '%s' "$path" | sed 's#^/##; s#[^A-Za-z0-9._-]#_#g')"
    cp -a "$path" "$BACKUP_DIR/$backup_name"
  fi
done
if [ -e "$WHM_ICON_DIR/help4-disk-usage.png" ]; then
  cp -a "$WHM_ICON_DIR/help4-disk-usage.png" "$BACKUP_DIR/usr_local_cpanel_whostmgr_docroot_addon_plugins_help4-disk-usage.png"
fi

install -d -m 0755 "$APP_DIR/bin" "$WHM_CGI_DIR" "$WHM_TEMPLATE_DIR" "$WHM_STATIC_DIR" "$WHM_ICON_DIR" "$CPANEL_DIR" /var/cpanel/apps
install -d -m 0755 "$CACHE_DIR"
install -d -m 0750 "$CACHE_DIR/accounts"
install -d -m 0755 "$LOCK_DIR"
touch "$LOCK_DIR/scan.lock"
chmod 0666 "$LOCK_DIR/scan.lock"

if [ ! -e "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<'JSON'
{
   "credit_prefix" : "Built by",
   "cpanel_min_interval_seconds" : 300,
   "cpanel_refreshes_per_hour" : 3,
   "cpanel_scan_max_seconds" : 60,
   "display_name" : "Disk Usage Audit",
   "package_overrides" : {},
   "release_url" : "https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.4.tar.gz",
   "scan_lock_dir" : "/var/cpanel/help4-disk-usage/locks",
   "update_manifest_url" : "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json",
   "whm_scan_max_seconds" : 90
}
JSON
  chmod 0644 "$CONFIG_FILE"
fi

CONFIG_FILE="$CONFIG_FILE" RELEASE_URL="$RELEASE_URL" UPDATE_MANIFEST_URL="$UPDATE_MANIFEST_URL" perl -MJSON::PP -0777 -e '
  my $path = $ENV{CONFIG_FILE};
  my $raw = "";
  if (open my $fh, "<", $path) { local $/; $raw = <$fh>; close $fh; }
  my $cfg = eval { decode_json($raw) } || {};
  $cfg->{display_name} ||= "Disk Usage Audit";
  $cfg->{credit_prefix} ||= "Built by";
  if (($cfg->{release_url} || "") =~ m{\Ahttps://github\.com/Help4Network/help4-disk-usage/archive/refs/(?:heads/main|tags/v[0-9.]+)\.tar\.gz\z}) {
    $cfg->{release_url} = $ENV{RELEASE_URL};
  }
  $cfg->{release_url} ||= $ENV{RELEASE_URL};
  $cfg->{update_manifest_url} ||= $ENV{UPDATE_MANIFEST_URL};
  open my $out, ">", "$path.$$" or die "cannot write config temp: $!";
  print {$out} JSON::PP->new->canonical->pretty->encode($cfg);
  close $out or die "cannot close config temp: $!";
  rename "$path.$$", $path or die "cannot replace config: $!";
'
chmod 0644 "$CONFIG_FILE"

install -m 0755 "$ROOT_DIR/src/bin/help4-disk-usage-scan" "$APP_DIR/bin/help4-disk-usage-scan"
install -m 0755 "$ROOT_DIR/src/bin/help4-disk-usage-update" "$APP_DIR/bin/help4-disk-usage-update"
install -m 0755 "$ROOT_DIR/src/whm/index.cgi" "$WHM_CGI_DIR/index.cgi"
install -m 0644 "$ROOT_DIR/src/whm/templates/index.tmpl" "$WHM_TEMPLATE_DIR/index.tmpl"
install -m 0644 "$ROOT_DIR/src/static/help4-disk-usage-whm.css" "$WHM_STATIC_DIR/help4-disk-usage-whm.css"
install -m 0644 "$ROOT_DIR/src/static/help4-disk-usage.png" "$WHM_ICON_DIR/help4-disk-usage.png"

install -m 0755 "$ROOT_DIR/src/cpanel/index.live.pl" "$CPANEL_DIR/index.live.pl"
install -m 0644 "$ROOT_DIR/src/static/help4-disk-usage.css" "$CPANEL_DIR/help4-disk-usage.css"
install -m 0644 "$ROOT_DIR/src/static/help4-disk-usage.svg" "$CPANEL_DIR/help4-disk-usage.svg"

install -m 0644 "$ROOT_DIR/packaging/help4_disk_usage.conf" /var/cpanel/apps/help4_disk_usage.conf
/usr/local/cpanel/bin/register_appconfig /var/cpanel/apps/help4_disk_usage.conf

/usr/local/cpanel/scripts/install_plugin "$ROOT_DIR/packaging" >/dev/null

cat > "$CRON_FILE" <<'CRON'
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/cpanel/3rdparty/help4-disk-usage/bin

17 */6 * * * root nice -n 10 ionice -c2 -n7 /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope all --write-cache --lock-dir /var/cpanel/help4-disk-usage/locks >> /var/log/help4-disk-usage-scan.log 2>&1
CRON
chmod 0644 "$CRON_FILE"

INSTALL_META="$INSTALL_META" VERSION="$VERSION" RELEASE_URL="$RELEASE_URL" UPDATE_MANIFEST_URL="$UPDATE_MANIFEST_URL" BACKUP_DIR="$BACKUP_DIR" perl -MJSON::PP -e '
  my $meta = {
    app => "Help4 Disk Usage",
    version => $ENV{VERSION} || "",
    installed_at => scalar gmtime() . "Z",
    release_url => $ENV{RELEASE_URL} || "",
    update_manifest_url => $ENV{UPDATE_MANIFEST_URL} || "",
    backup_dir => $ENV{BACKUP_DIR} || "",
  };
  open my $fh, ">", $ENV{INSTALL_META} or die "cannot write install metadata: $!";
  print {$fh} JSON::PP->new->canonical->pretty->encode($meta);
  close $fh or die "cannot close install metadata: $!";
'
chmod 0644 "$INSTALL_META"

echo "Help4 Disk Usage installed."
echo "Version: $VERSION"
echo "Backup/snapshot: $BACKUP_DIR"
echo "WHM URL path: /cgi/help4_disk_usage/index.cgi"
echo "cPanel Jupiter path: help4_disk_usage/index.live.pl"
