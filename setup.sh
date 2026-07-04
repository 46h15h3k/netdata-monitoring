#!/usr/bin/env bash
#
# setup.sh - Install and configure Netdata on Amazon Linux 2023
#
# Usage: sudo ./setup.sh
#
set -euo pipefail

LOG_FILE="/var/log/netdata-setup.log"
ALERT_CONF_DIR="/etc/netdata/health.d"
ALERT_CONF_FILE="${ALERT_CONF_DIR}/cpu_custom.conf"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

install_netdata() {
    if systemctl is-active --quiet netdata 2>/dev/null; then
        log "Netdata is already installed and running. Skipping install."
        return
    fi

    log "Downloading Netdata kickstart script..."
    curl -fsSL https://get.netdata.cloud/kickstart.sh -o /tmp/netdata-kickstart.sh

    log "Running Netdata kickstart installer (stable channel, telemetry disabled)..."
    sh /tmp/netdata-kickstart.sh --stable-channel --disable-telemetry --non-interactive

    log "Netdata installation complete."
}

configure_alert() {
    log "Configuring custom CPU usage alert (warn > 80%, crit > 90%)..."
    mkdir -p "$ALERT_CONF_DIR"

    cat > "$ALERT_CONF_FILE" <<'EOF'
template: cpu_usage_high
      on: system.cpu
   class: Utilization
    type: System
component: CPU
    calc: $user + $system
   units: %
   every: 10s
    warn: $this > 80
    crit: $this > 90
    info: CPU utilization is high
EOF

    log "Alert configuration written to ${ALERT_CONF_FILE}"
}

restart_netdata() {
    log "Restarting Netdata to apply configuration..."
    systemctl restart netdata
    systemctl enable netdata
}

verify() {
    log "Verifying Netdata service status..."
    if systemctl is-active --quiet netdata; then
        log "Netdata is running."
        local ip
        ip=$(curl -s -m 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<your-ec2-ip>")
        log "Dashboard should be reachable at: http://${ip}:19999"
        log "Recommended: access via SSH tunnel instead of exposing port 19999 publicly:"
        log "  ssh -i /path/to/key.pem -L 19999:localhost:19999 ec2-user@${ip}"
    else
        log "ERROR: Netdata failed to start. Check 'journalctl -u netdata' for details."
        exit 1
    fi
}

main() {
    require_root
    log "=== Starting Netdata setup ==="
    install_netdata
    configure_alert
    restart_netdata
    verify
    log "=== Setup complete ==="
}

main "$@"
