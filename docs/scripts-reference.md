# Scripts Reference – Monitoring Stack

> Quick reference for all monitoring scripts. Every script, its purpose, usage, and what it covers.

---

## Script Overview

| Script | Category | Description |
|---|---|---|
| `system-info.sh` | System | Full OS/hardware/network summary with ASCII banner |
| `health-report.sh` | System | One-stop infrastructure dashboard |
| `alert-check.sh` | Alerting | Threshold-based alerts with log output |
| `cpu-monitor.sh` | Resources | CPU usage, load averages, per-core stats |
| `memory-monitor.sh` | Resources | RAM, swap, OOM detection, pressure metrics |
| `disk-monitor.sh` | Resources | Filesystem usage, inodes, large files |
| `network-monitor.sh` | Network | Interfaces, routing, ports, connectivity |
| `process-monitor.sh` | Processes | Top consumers, zombies, per-user stats |
| `service-monitor.sh` | Services | systemd service status, failed units |
| `uptime-monitor.sh` | System | Uptime, load classification, reboot history |
| `log-monitor.sh` | Logs | Error scanning, auth failures, OOM events |
| `user-audit.sh` | Security | Users, sudo access, SSH keys, login audit |
| `backup.sh` | Operations | Compressed tar backup with rotation |
| `docker-monitor.sh` | Containers | Docker containers, images, volumes, networks |

---

## Detailed Reference

---

### `system-info.sh`

**Purpose:** Professional system overview, similar to `neofetch` but for sysadmins. First script to run on a new machine.

**Usage:**
```bash
./scripts/system-info.sh
```

**Covers:**
- Hostname, OS name, kernel version, architecture
- CPU model, cores, threads, speed
- RAM total, used, available; Swap info
- Root disk usage; all mounted filesystems
- Network interfaces, IP, gateway, DNS
- Uptime, running/failed service counts
- Docker status (if installed)
- Cloud platform detection (AWS/GCP/Azure)

**Sample output header:**
```
   ███████╗██╗   ██╗███████╗    ██╗███╗   ██╗███████╗ ██████╗
   ...
  ┌─ 🖥️  Identity & OS ─────────────────────────────────
  │  Hostname  : server01.example.com
  │  OS        : Ubuntu 22.04.3 LTS
  │  Kernel    : 5.15.0-91-generic
```

---

### `health-report.sh`

**Purpose:** Comprehensive infrastructure health dashboard. Run this to get a complete picture of the system in one output.

**Usage:**
```bash
./scripts/health-report.sh
```

**Covers:**
- System identity, OS, kernel
- Hardware summary
- CPU usage + load classification
- Memory usage + threshold check
- Disk usage for all filesystems
- Network interface status + internet check
- Critical service statuses
- Security snapshot (logged-in users, failed SSH, last reboot)
- Pending package updates

---

### `alert-check.sh`

**Purpose:** Checks resource utilization against configurable thresholds. Designed to run from cron and log results.

**Usage:**
```bash
./scripts/alert-check.sh              # Color output to terminal
./scripts/alert-check.sh --no-color   # Plain output for cron/email
```

**Configurable thresholds:**
```bash
CPU_THRESHOLD=80       # %
MEMORY_THRESHOLD=80    # %
SWAP_THRESHOLD=60      # %
DISK_THRESHOLD=80      # % (applied to all mounted filesystems)
LOAD_THRESHOLD=2       # × number of CPU cores
```

**Output levels:**
- `[ OK ]` – Green: within normal range
- `[WARN]` – Yellow: approaching threshold
- `[CRIT]` – Red: threshold exceeded

**Log file:** `logs/alert-check.log` (auto-created)

**Cron example:**
```bash
*/15 * * * * /path/to/scripts/alert-check.sh --no-color >> /var/log/alerts.log 2>&1
```

---

### `cpu-monitor.sh`

**Purpose:** Detailed CPU analysis including hardware specs, real-time usage, and load classification.

**Usage:**
```bash
./scripts/cpu-monitor.sh
```

**Covers:**
- CPU model, cores, threads, sockets, architecture
- Current CPU usage % (measured via `/proc/stat` – more accurate than `top`)
- Load averages (1/5/15 min) with classification: LOW / MODERATE / HIGH / CRITICAL
- Per-core usage (requires `sysstat` for `mpstat`, fallback to `/proc/stat`)
- Top 10 CPU-consuming processes
- Kernel stats: context switches, interrupts, total processes created since boot

---

### `memory-monitor.sh`

**Purpose:** Detailed memory analysis covering RAM, swap, kernel memory indicators, and OOM detection.

**Usage:**
```bash
./scripts/memory-monitor.sh
```

**Covers:**
- Total RAM, used, available (with % calculation)
- Swap: total, used, free with threshold check
- Memory pressure: cached, buffers, slab, dirty pages
- OOM killer event detection via `dmesg`
- Top 10 memory-consuming processes
- Process count per user

---

### `disk-monitor.sh`

**Purpose:** Complete disk health view – usage, inodes, I/O, large directories, and oversized files.

**Usage:**
```bash
./scripts/disk-monitor.sh
```

**Covers:**
- All mounted filesystems with color-coded usage %
- Inode usage (critical for systems with many small files)
- Disk I/O statistics (`iostat` if available, `/proc/diskstats` fallback)
- Top 5 largest subdirectories in `/var`, `/tmp`, `/home`, `/opt`
- Files larger than 100MB in `/home` and `/var`

---

### `network-monitor.sh`

**Purpose:** Network health check covering interfaces, routing, DNS, ports, and traffic statistics.

**Usage:**
```bash
./scripts/network-monitor.sh
```

**Covers:**
- All interfaces: state (UP/DOWN) and IP addresses
- Routing table and default gateway
- DNS server configuration (`/etc/resolv.conf` + `resolvectl`)
- Connectivity tests: ping to 8.8.8.8, 1.1.1.1, google.com; HTTPS check
- Active connection summary (total, TCP established, listening, UDP)
- Listening ports with process names (`ss -tulnp`)
- Per-interface traffic statistics (RX/TX bytes and packets from `/sys/class/net`)
- `/etc/hosts` entries

---

### `process-monitor.sh`

**Purpose:** Process visibility – top consumers, zombie detection, per-user and per-thread analysis.

**Usage:**
```bash
./scripts/process-monitor.sh
```

**Covers:**
- Process summary: total, running, sleeping, zombie, thread count
- Zombie process alert with PPID and details
- Top 10 CPU consumers (with color highlighting for >50% and >20%)
- Top 10 memory consumers with RSS (resident set size)
- Process count and thread count per user
- Top 10 processes by thread count
- Top 10 longest-running processes by elapsed time

---

### `service-monitor.sh`

**Purpose:** Comprehensive systemd service audit across core OS, security, web/app, and DevOps tool categories.

**Usage:**
```bash
./scripts/service-monitor.sh
```

**Service groups:**
- **Core OS:** ssh, cron, rsyslog, systemd-journald, ufw
- **Security:** fail2ban, apparmor, auditd
- **Web/App:** nginx, apache2, mysql, postgresql, redis-server
- **DevOps:** docker, containerd, prometheus, node_exporter, grafana-server

**For each service shows:**
- Active state: `RUNNING` / `INACTIVE` / `FAILED`
- Enabled state (starts at boot)
- Start timestamp for running services
- Last 3 journal lines for failed services
- Suggested fix command

**Also shows:** All system-wide failed units + tips for investigation

---

### `uptime-monitor.sh`

**Purpose:** System uptime, boot time, load average classification, user sessions, and reboot history.

**Usage:**
```bash
./scripts/uptime-monitor.sh
```

**Covers:**
- Uptime in days, hours, minutes, seconds (from `/proc/uptime`)
- Exact boot timestamp
- High-uptime warning (>30 days → maintenance recommended)
- Load averages with classification: LOW / MODERATE / WARNING / CRITICAL
- Currently logged-in user sessions (user, TTY, login time, source)
- Last 5 system reboots (from `last reboot`)
- Current user cron jobs + count of system cron files

---

### `log-monitor.sh`

**Purpose:** Log scanning for errors, OOM events, authentication failures, failed systemd units, and kernel errors.

**Usage:**
```bash
./scripts/log-monitor.sh             # Basic (limited to readable logs)
sudo ./scripts/log-monitor.sh        # Full (includes auth.log, secure)
```

**Covers:**
- Auto-detects syslog location (`/var/log/syslog` or `/var/log/messages`)
- Recent ERROR/CRITICAL/FAILED/FATAL lines from syslog
- Warning lines from syslog
- OOM killer events from `dmesg` + syslog
- Authentication failures from `auth.log`/`secure`
- Top SSH brute-force source IPs
- All failed systemd units (system-wide)
- journald error-priority entries from the last hour
- Disk/hardware errors in the journal
- Kernel errors from `dmesg`

---

### `user-audit.sh`

**Purpose:** Security-focused user account audit – who has access, sudo rights, SSH keys, and recent login failures.

**Usage:**
```bash
./scripts/user-audit.sh              # Basic
sudo ./scripts/user-audit.sh         # Full (includes shadow, auth.log)
```

**Covers:**
- Currently logged-in users with session details
- All system users from `/etc/passwd` (color-coded by type)
- Users with interactive login shells
- Sudo-capable users (sudo/wheel/admin groups)
- Direct sudoers entries
- Accounts with empty passwords (requires root)
- Accounts with UID 0 (root equivalents – security red flag)
- Last login time for each user
- SSH authorized keys audit (per user)
- Recent failed SSH logins (last 20)
- Top source IPs for SSH brute force

---

### `backup.sh`

**Purpose:** Compressed tar.gz backup with timestamp, integrity verification, and automatic rotation.

**Usage:**
```bash
./scripts/backup.sh                     # Backs up $HOME to ./backups/
./scripts/backup.sh /etc               # Back up /etc
./scripts/backup.sh /var/www /mnt/nas  # Custom source and destination
```

**Features:**
- Auto-creates destination directory
- Filename format: `backup_<hostname>_<source>_<timestamp>.tar.gz`
- Integrity check with `tar -tzf` after backup
- Rotation: keeps last N backups (configurable, default 5)
- Reports backup size and duration
- Disk space check on destination
- Restore instructions in output

**Configurable:**
```bash
MAX_BACKUPS=5        # How many copies to keep
```

---

### `docker-monitor.sh`

**Purpose:** Docker environment health check – daemon status, containers, images, volumes, networks, disk usage.

**Usage:**
```bash
./scripts/docker-monitor.sh
```

**Covers:**
- Docker installation and daemon status check (graceful if not installed)
- Docker version and storage driver
- Running containers with status and ports
- Live container resource usage (`docker stats --no-stream`)
- Stopped/exited containers with exit codes
- Docker images inventory with size
- Dangling image detection
- Docker volumes list
- Docker networks list
- Docker system disk usage (`docker system df`)

---

## Script Permissions Reference

```bash
# Make all scripts executable at once
chmod +x scripts/*.sh

# Verify
ls -la scripts/ | grep ".sh"
```

Expected permissions: `-rwxr-xr-x`

---

## Author

**Vatsalya Patel** – Linux Admin | Cloud Support Engineer  
GitHub: [github.com/lnvpatel](https://github.com/lnvpatel)  
LinkedIn: [linkedin.com/in/lnvpatel](https://linkedin.com/in/lnvpatel)
