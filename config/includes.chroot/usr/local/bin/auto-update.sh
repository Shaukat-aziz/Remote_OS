#!/bin/bash
set -euo pipefail

readonly LOCK_FILE=/run/remote-os-auto-update.lock
readonly RUSTDESK_API=https://api.github.com/repos/rustdesk/rustdesk/releases/latest
readonly DOWNLOAD_DIR=/var/cache/remote-os-updates

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

logger -t remote-os-auto-update "checking for application updates"
install -d -m 0755 "$DOWNLOAD_DIR"
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y --no-install-recommends install tailscale

rustdesk_url="$(
    curl --fail --silent --show-error \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: Remote_OS-updater' "$RUSTDESK_API" |
        sed -n 's/.*"browser_download_url": "\(.*\.\(amd64\|x86_64\)\.deb\)".*/\1/p' |
        head -n 1
)"

if [ -z "$rustdesk_url" ]; then
    logger -t remote-os-auto-update "RustDesk amd64 release asset was not found"
    exit 0
fi

rustdesk_deb="$DOWNLOAD_DIR/$(basename "$rustdesk_url")"
curl --fail --silent --show-error --location "$rustdesk_url" --output "$rustdesk_deb"
apt-get -y --no-install-recommends install "$rustdesk_deb"
rm -f "$rustdesk_deb"

systemctl try-restart tailscaled.service
logger -t remote-os-auto-update "application update check completed"
