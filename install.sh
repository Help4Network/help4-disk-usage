#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Install must run as root on a cPanel & WHM server." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="/root/help4-disk-usage-install-backups/${STAMP}"

APP_DIR="/usr/local/cpanel/3rdparty/help4-disk-usage"
WHM_CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage"
WHM_STATIC_DIR="/usr/local/cpanel/whostmgr/docroot/help4-disk-usage"
WHM_ICON_DIR="/usr/local/cpanel/whostmgr/docroot/addon_plugins"
CPANEL_DIR="/usr/local/cpanel/base/frontend/jupiter/help4_disk_usage"
CACHE_DIR="/var/cpanel/help4-disk-usage"
LOCK_DIR="$CACHE_DIR/locks"
CONFIG_FILE="$CACHE_DIR/config.json"
APP_CONF="/var/cpanel/apps/help4_disk_usage.conf"
CRON_FILE="/etc/cron.d/help4-disk-usage"

for required in /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/scripts/install_plugin; do
  if [ ! -x "$required" ]; then
    echo "Missing required cPanel command: $required" >&2
    exit 2
  fi
done

mkdir -p "$BACKUP_DIR"
for path in "$APP_DIR" "$WHM_CGI_DIR" "$WHM_STATIC_DIR" "$CPANEL_DIR" "$CONFIG_FILE" "$APP_CONF" "$CRON_FILE"; do
  if [ -e "$path" ]; then
    backup_name="$(printf '%s' "$path" | sed 's#^/##; s#[^A-Za-z0-9._-]#_#g')"
    cp -a "$path" "$BACKUP_DIR/$backup_name"
  fi
done
if [ -e "$WHM_ICON_DIR/help4-disk-usage.png" ]; then
  cp -a "$WHM_ICON_DIR/help4-disk-usage.png" "$BACKUP_DIR/usr_local_cpanel_whostmgr_docroot_addon_plugins_help4-disk-usage.png"
fi

install -d -m 0755 "$APP_DIR/bin" "$WHM_CGI_DIR" "$WHM_STATIC_DIR" "$WHM_ICON_DIR" "$CPANEL_DIR" /var/cpanel/apps
install -d -m 0750 "$CACHE_DIR" "$CACHE_DIR/accounts"
install -d -m 0755 "$LOCK_DIR"
touch "$LOCK_DIR/scan.lock"
chmod 0666 "$LOCK_DIR/scan.lock"

if [ ! -e "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<'JSON'
{
   "cpanel_min_interval_seconds" : 300,
   "cpanel_refreshes_per_hour" : 3,
   "cpanel_scan_max_seconds" : 60,
   "package_overrides" : {},
   "scan_lock_dir" : "/var/cpanel/help4-disk-usage/locks",
   "whm_scan_max_seconds" : 90
}
JSON
  chmod 0644 "$CONFIG_FILE"
fi

install -m 0755 "$ROOT_DIR/src/bin/help4-disk-usage-scan" "$APP_DIR/bin/help4-disk-usage-scan"
install -m 0755 "$ROOT_DIR/src/whm/index.cgi" "$WHM_CGI_DIR/index.cgi"
install -m 0644 "$ROOT_DIR/src/static/help4-disk-usage.css" "$WHM_STATIC_DIR/help4-disk-usage.css"
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

echo "Help4 Disk Usage installed."
echo "Backup/snapshot: $BACKUP_DIR"
echo "WHM URL path: /cgi/help4_disk_usage/index.cgi"
echo "cPanel Jupiter path: help4_disk_usage/index.live.pl"
