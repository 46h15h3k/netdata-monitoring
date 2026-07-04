#!/usr/bin/env bash
#
# test_dashboard.sh - Generate load to validate Netdata is capturing metrics
#
# Usage: ./test_dashboard.sh [duration_seconds]
#
set -euo pipefail

DURATION="${1:-60}"
LOG_FILE="/var/log/netdata-test.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_prereqs() {
    for cmd in stress-ng dd; do
        if ! command -v "$cmd" &>/dev/null; then
            log "'$cmd' not found. Attempting to install..."
            if command -v dnf &>/dev/null; then
                sudo dnf install -y stress-ng coreutils
            elif command -v yum &>/dev/null; then
                sudo yum install -y stress-ng coreutils
            else
                log "ERROR: could not auto-install $cmd. Please install it manually."
                exit 1
            fi
        fi
    done
}

cpu_load() {
    log "Generating CPU load for ${DURATION}s across all cores (target: >80% to trigger alert)..."
    stress-ng --cpu "$(nproc)" --cpu-load 90 --timeout "${DURATION}s" &
    CPU_PID=$!
}

memory_load() {
    log "Generating memory pressure for ${DURATION}s (256M workers x2)..."
    stress-ng --vm 2 --vm-bytes 256M --timeout "${DURATION}s" &
    MEM_PID=$!
}

disk_load() {
    log "Generating disk I/O load (writing and deleting a 500M test file)..."
    dd if=/dev/zero of=/tmp/netdata_test_file bs=1M count=500 oflag=direct status=none || \
        dd if=/dev/zero of=/tmp/netdata_test_file bs=1M count=500 status=none
    sync
    rm -f /tmp/netdata_test_file
    log "Disk I/O burst complete."
}

wait_for_jobs() {
    log "Waiting for background load generators to finish..."
    wait "$CPU_PID" "$MEM_PID" 2>/dev/null || true
}

main() {
    log "=== Starting dashboard load test (duration: ${DURATION}s) ==="
    check_prereqs
    cpu_load
    memory_load
    disk_load
    wait_for_jobs
    log "=== Load test complete. Check the Netdata dashboard for CPU/memory/disk spikes"
    log "and confirm the cpu_usage_high alert fired if load exceeded 80%. ==="
}

main "$@"
