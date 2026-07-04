#!/usr/bin/env bash
#
# cleanup.sh - Remove Netdata and associated configuration from the system
#
# Usage: sudo ./cleanup.sh
#
set -euo pipefail

LOG_FILE="/var/log/netdata-cleanup.log"
UNINSTALL_SCRIPT="/usr/libexec/netdata/netdata-uninstaller.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

stop_netdata() {
    if systemctl is-active --quiet netdata 2>/dev/null; then
        log "Stopping Netdata service..."
        systemctl stop netdata
        systemctl disable netdata
    else
        log "Netdata service not running or not installed."
    fi
}

uninstall_netdata() {
    if [[ -x "$UNINSTALL_SCRIPT" ]]; then
        log "Running official Netdata uninstaller..."
        yes | "$UNINSTALL_SCRIPT" --yes --force || true
    else
        log "Official uninstaller not found. Removing files manually..."
        rm -rf /etc/netdata
        rm -rf /var/lib/netdata
        rm -rf /var/cache/netdata
        rm -rf /var/log/netdata
        rm -rf /usr/libexec/netdata
        rm -rf /usr/share/netdata
        rm -f /etc/systemd/system/netdata.service
        systemctl daemon-reload
    fi
}

remove_test_artifacts() {
    log "Removing leftover test files, if any..."
    rm -f /tmp/netdata_test_file
}

verify_removed() {
    if command -v netdata &>/dev/null || systemctl list-unit-files | grep -q netdata; then
        log "WARNING: Some Netdata components may still be present. Manual check recommended."
    else
        log "Netdata has been fully removed."
    fi
}

main() {
    require_root
    log "=== Starting Netdata cleanup ==="
    stop_netdata
    uninstall_netdata
    remove_test_artifacts
    verify_removed
    log "=== Cleanup complete ==="
}

main "$@"
