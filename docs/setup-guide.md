# Setup Guide – Monitoring Stack

> A step-by-step guide to deploying and running the Linux monitoring scripts on any Debian/Ubuntu or RHEL/CentOS based system.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Linux OS | Ubuntu 20.04+ / Debian 11+ / CentOS 7+ / RHEL 8+ |
| Bash | Version 4.0+ (`bash --version`) |
| Standard tools | `top`, `free`, `df`, `ps`, `ss`, `ip`, `ping`, `curl` (pre-installed on most distros) |
| Optional tools | `sysstat` (for `mpstat`/`iostat`), `fail2ban`, `docker` |

### Check your Bash version
```bash
bash --version
```

### Install optional dependencies (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y sysstat curl net-tools
```

### Install optional dependencies (RHEL/CentOS)
```bash
sudo yum install -y sysstat curl net-tools
```

---

## 1. Clone the Repository

```bash
git clone https://github.com/lnvpatel/monitoring-stack.git
cd monitoring-stack
```

---

## 2. Make All Scripts Executable

```bash
chmod +x scripts/*.sh
```

Verify permissions:
```bash
ls -la scripts/
```

Expected output:
```
-rwxr-xr-x 1 user user ... alert-check.sh
-rwxr-xr-x 1 user user ... backup.sh
...
```

---

## 3. Run Individual Scripts

All scripts can be run directly from the repository root:

```bash
./scripts/system-info.sh       # Full system overview
./scripts/health-report.sh     # Infrastructure dashboard
./scripts/alert-check.sh       # Threshold-based alerting
./scripts/cpu-monitor.sh       # CPU details
./scripts/memory-monitor.sh    # Memory and swap
./scripts/disk-monitor.sh      # Disk usage and inodes
./scripts/network-monitor.sh   # Network interfaces and ports
./scripts/process-monitor.sh   # Top processes and zombies
./scripts/service-monitor.sh   # systemd service status
./scripts/uptime-monitor.sh    # Uptime and load averages
./scripts/log-monitor.sh       # Log error scanning
./scripts/user-audit.sh        # User and sudo audit
./scripts/backup.sh            # Create a compressed backup
./scripts/docker-monitor.sh    # Docker containers and images
```

### Run with sudo for full access
Some scripts read protected log files (`/var/log/auth.log`, `/etc/shadow`):

```bash
sudo ./scripts/user-audit.sh
sudo ./scripts/log-monitor.sh
```

---

## 4. Configure Alert Thresholds

Edit `scripts/alert-check.sh` to set your own thresholds:

```bash
CPU_THRESHOLD=80      # Alert if CPU > 80%
MEMORY_THRESHOLD=80   # Alert if RAM > 80%
SWAP_THRESHOLD=60     # Alert if Swap > 60%
DISK_THRESHOLD=80     # Alert if any disk > 80%
LOAD_THRESHOLD=2      # Alert if load avg > (cores × 2)
```

---

## 5. Configure Backup Script

Edit `scripts/backup.sh` defaults, or pass arguments:

```bash
# Back up /etc to default ./backups/ location
./scripts/backup.sh /etc

# Custom source and destination
./scripts/backup.sh /var/www /mnt/nas/backups

# Keep only 3 most recent backups (edit inside script)
MAX_BACKUPS=3
```

---

## 6. Automate with Cron

### Open your crontab
```bash
crontab -e
```

### Example cron jobs
```bash
# Run alert check every 15 minutes (log output)
*/15 * * * * /path/to/monitoring-stack/scripts/alert-check.sh --no-color >> /var/log/alert-check.log 2>&1

# Run health report every hour
0 * * * * /path/to/monitoring-stack/scripts/health-report.sh --no-color >> /var/log/health-report.log 2>&1

# Daily backup at 2:00 AM
0 2 * * * /path/to/monitoring-stack/scripts/backup.sh /etc /var/backups/etc >> /var/log/backup.log 2>&1

# Weekly user audit on Sundays at midnight
0 0 * * 0 /path/to/monitoring-stack/scripts/user-audit.sh >> /var/log/user-audit.log 2>&1
```

> **Tip:** Use absolute paths in cron jobs. Check with `which bash` and `pwd`.

---

## 7. View Alert Logs

Alert logs are written to `logs/alert-check.log`:

```bash
# View the full log
cat logs/alert-check.log

# View last 50 lines
tail -50 logs/alert-check.log

# Watch live
tail -f logs/alert-check.log

# Search for CRITICAL entries
grep "CRIT" logs/alert-check.log
```

---

## 8. Setting Up the Full Observability Stack (Prometheus + Grafana)

For the complete metrics stack using Docker Compose:

```bash
# Start all monitoring services
cd docker/
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f prometheus
docker compose logs -f grafana
```

Access:
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (default: admin/admin)
- **Node Exporter**: http://localhost:9100/metrics

---

## 9. Troubleshooting Script Issues

| Error | Fix |
|---|---|
| `Permission denied` | Run `chmod +x scripts/*.sh` |
| `command not found: mpstat` | `sudo apt install sysstat` |
| Script exits with no output | Run manually and check for errors |
| `logs/` directory not found | It's created automatically on first run |
| Docker script exits immediately | Docker not installed – expected, script handles it gracefully |

---

## Cloud Deployment (AWS / GCP / Azure)

These scripts run on any Linux VM in the cloud without modification:

```bash
# On AWS EC2 (Amazon Linux 2)
sudo yum install -y git
git clone https://github.com/lnvpatel/monitoring-stack.git
cd monitoring-stack && chmod +x scripts/*.sh
./scripts/system-info.sh    # Will detect AWS EC2 automatically
```

```bash
# On GCP Compute Engine (Debian/Ubuntu)
sudo apt install -y git
git clone https://github.com/lnvpatel/monitoring-stack.git
cd monitoring-stack && chmod +x scripts/*.sh
./scripts/system-info.sh    # Will detect GCP automatically
```

---

## Author

**Vatsalya Patel** – Linux Admin | Cloud Support Engineer  
GitHub: [github.com/lnvpatel](https://github.com/lnvpatel)  
LinkedIn: [linkedin.com/in/lnvpatel](https://linkedin.com/in/lnvpatel)
