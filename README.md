# Simple Monitoring — Netdata on AWS EC2

A basic real-time monitoring dashboard for a Linux server using [Netdata](https://github.com/netdata/netdata), deployed and automated end-to-end with shell scripting on AWS EC2.

## Overview

This project sets up system-level observability (CPU, memory, disk I/O) on an Amazon Linux 2023 EC2 instance, with a custom health alert and repeatable automation scripts — install, test, and teardown.

## Architecture

```
                 SSH Tunnel (port 19999)
   [Local Browser] ───────────────────► [EC2 Instance]
                                            │
                                            ▼
                                     Netdata Agent
                              (collects CPU / RAM / Disk metrics)
                                            │
                                            ▼
                                  Custom health.d alert
                                (CPU > 80% warn, > 90% crit)
```

## What This Demonstrates

- Linux system administration on AWS EC2 (Amazon Linux 2023)
- Installing and configuring a production-grade monitoring agent
- Writing custom Netdata health alert templates
- Bash scripting with `set -euo pipefail`, logging, and idempotency checks
- Basic security hygiene — restricting the dashboard port and preferring SSH tunneling over public exposure
- Load testing / validation of monitoring setups (`stress-ng`)

## Scripts

| Script | Purpose |
|---|---|
| `setup.sh` | Installs Netdata via the official kickstart script, configures a custom CPU alert (`health.d/cpu_custom.conf`), and starts the service |
| `test_dashboard.sh` | Generates CPU, memory, and disk load using `stress-ng`/`dd` to validate metrics appear on the dashboard and the alert fires |
| `cleanup.sh` | Stops and fully uninstalls Netdata, removing all config, logs, and cache |

## Usage

```bash
# 1. Install and configure Netdata
sudo ./setup.sh

# 2. Access the dashboard securely via SSH tunnel (run from your local machine)
ssh -i /path/to/key.pem -L 19999:localhost:19999 ec2-user@<EC2_PUBLIC_IP>
# then open http://localhost:19999 in your browser

# 3. Generate load and validate the dashboard/alert
./test_dashboard.sh 60          # runs for 60 seconds

# 4. Tear down when done
sudo ./cleanup.sh
```

## Custom Alert

`setup.sh` writes the following to `/etc/netdata/health.d/cpu_custom.conf`:

```
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
```

## Security Notes

- The EC2 Security Group only opens port 22 (SSH) and 19999 (Netdata) to a specific IP — never `0.0.0.0/0`.
- Preferred access pattern is an SSH tunnel rather than exposing the dashboard publicly.

## Skills Demonstrated

`AWS EC2` · `Linux Administration` · `Bash Scripting` · `Monitoring & Observability` · `Netdata` · `Infrastructure Automation`
