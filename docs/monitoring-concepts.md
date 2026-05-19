# Monitoring Concepts – Linux Admin Reference

> A practical guide to infrastructure monitoring concepts for Linux Admin and Cloud Support Engineers. Written for freshers — explains the **what**, **why**, and **how** behind each metric.

---

## 1. Why Infrastructure Monitoring Matters

In production environments, things go wrong silently. A disk fills up at 3 AM, a service crashes, memory slowly leaks over hours, or a DDoS attack floods SSH. Without monitoring, you find out when the customer calls.

Good monitoring means:
- **Proactive detection** – catch problems before users are impacted
- **Faster troubleshooting** – know where to look immediately
- **Capacity planning** – know when to scale before you hit limits
- **Compliance & auditing** – prove uptime and track changes

---

## 2. CPU Metrics Explained

### What is CPU Usage?
CPU usage is the percentage of time the processor is busy doing work (vs idle). `top`, `htop`, and `/proc/stat` measure this.

```bash
top -bn1 | grep "Cpu(s)"
# Output: Cpu(s): 12.5 us, 3.2 sy, 0.0 ni, 82.1 id, 1.8 wa, ...
```

| Field | Meaning |
|---|---|
| `us` | User space (your applications) |
| `sy` | Kernel/system calls |
| `ni` | "niced" low-priority processes |
| `id` | **Idle** – the lower this is, the busier the CPU |
| `wa` | **I/O Wait** – CPU waiting for disk/network. High wa = I/O bottleneck |
| `hi`/`si` | Hardware/software interrupt handling |

### What is Load Average?

Load average ≠ CPU usage. It measures the **average number of processes waiting to be scheduled** over 1, 5, and 15 minutes.

```bash
uptime
# output: load average: 0.52, 0.45, 0.38
```

**Rule of thumb:**
- **Load = number of cores** → 100% utilization, processes must queue
- **Load < number of cores** → healthy
- **Load > number of cores × 2** → system is overloaded

```bash
# Check how many cores you have
nproc
# or
grep -c "^processor" /proc/cpuinfo
```

> **Interview tip:** If load is 3.0 on a 4-core machine → 75% loaded (healthy). Same 3.0 on a 1-core machine → 300% overloaded!

---

## 3. Memory: RAM vs Swap

### RAM (Random Access Memory)
Fast, volatile memory. Processes use RAM to store data they're actively working with.

```bash
free -h
#               total        used        free      shared  buff/cache   available
# Mem:           15Gi       4.2Gi       6.1Gi       320Mi       4.9Gi      10.7Gi
```

| Column | Meaning |
|---|---|
| `total` | Physical RAM installed |
| `used` | RAM actively in use by processes |
| `free` | Completely unused RAM (often low — Linux uses it for caching) |
| `buff/cache` | Linux uses free RAM for disk cache — **this is good!** |
| **`available`** | **The real answer** — how much can new processes use (free + reclaimable cache) |

> **Common mistake:** People panic when `free` is low. Always look at `available` — Linux aggressively uses RAM for caching to speed up disk I/O.

### Swap
Virtual memory on disk. When RAM fills up, the kernel moves less-used pages here. Much slower than RAM (100-1000x).

```bash
free -h | grep Swap
# Swap:          2.0Gi       256Mi       1.7Gi
```

- **Swap in use ≠ disaster** — a little swap is normal
- **Heavy swap usage** = RAM pressure — processes are competing for memory
- **OOM Killer** — when swap is also full, the kernel kills processes. Check: `dmesg | grep "Out of memory"`

---

## 4. Disk: Blocks vs Inodes

### Disk Space (Blocks)
```bash
df -h
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda1        50G   12G   38G  24% /
```

### Inodes
Each file requires one inode (metadata record: owner, permissions, timestamps). You can run out of inodes even with free disk space — then you can't create new files!

```bash
df -i
# Filesystem      Inodes  IUsed   IFree IUse% Mounted on
# /dev/sda1      3276800  42000 3234800    2% /
```

> **Symptom:** `No space left on device` error but `df -h` shows free space → check `df -i`. Common cause: many small files (mail queues, tmp files, log rotation artifacts).

### Finding Large Files
```bash
# Find files larger than 100MB
find / -type f -size +100M 2>/dev/null

# Find 10 largest directories
du -sh /* 2>/dev/null | sort -rh | head -10

# Find largest files in /var
du -sh /var/*/ | sort -rh | head -10
```

---

## 5. Network Monitoring Concepts

### Network Interfaces
```bash
ip -brief address       # Quick overview
ip addr show            # Detailed with all addresses
ip link show            # Link layer info (MAC, MTU, state)
```

### TCP Connection States
```bash
ss -tn                  # All TCP connections
ss -tulnp               # All listening ports with process
```

| State | Meaning |
|---|---|
| `LISTEN` | Service waiting for connections |
| `ESTABLISHED` | Active connection |
| `TIME_WAIT` | Connection closing, waiting for final packets |
| `CLOSE_WAIT` | Remote end closed, local still open |
| `FIN_WAIT` | Local end sent FIN (closing) |

### Useful Network Commands
```bash
# Check internet connectivity
ping -c 4 8.8.8.8

# DNS resolution test
nslookup google.com
dig google.com

# Trace network path
traceroute google.com

# Check specific port
nc -zv google.com 443

# Capture traffic (requires tcpdump)
sudo tcpdump -i eth0 -n port 80
```

---

## 6. Service Monitoring with systemd

Most modern Linux distros use **systemd** to manage services.

### Key Commands
```bash
# Check service status
systemctl status nginx

# Start / Stop / Restart
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx      # reload config without restart

# Enable at boot / Disable
sudo systemctl enable nginx
sudo systemctl disable nginx

# List all running services
systemctl list-units --type=service --state=running

# List failed services
systemctl --failed

# View logs for a service
journalctl -u nginx -n 50 --no-pager
journalctl -u nginx --since "1 hour ago"
journalctl -xe                           # most recent errors
```

### Service States

| State | Meaning |
|---|---|
| `active (running)` | Healthy |
| `active (exited)` | One-shot service completed normally |
| `inactive (dead)` | Stopped (may be disabled) |
| `failed` | Crashed or error — investigate with `journalctl` |
| `activating` | Starting up |

---

## 7. Log Monitoring Basics

### Log Files Location
```bash
/var/log/syslog          # General system logs (Debian/Ubuntu)
/var/log/messages        # General system logs (RHEL/CentOS)
/var/log/auth.log        # Authentication logs (Debian/Ubuntu)
/var/log/secure          # Authentication logs (RHEL/CentOS)
/var/log/kern.log        # Kernel messages
/var/log/dmesg           # Boot-time kernel messages
/var/log/nginx/          # Nginx web server logs
/var/log/apache2/        # Apache web server logs
```

### Essential Log Commands
```bash
# View live log stream
tail -f /var/log/syslog

# Search for errors
grep -i "error\|failed\|critical" /var/log/syslog | tail -20

# Using journalctl (systemd)
journalctl -p err                        # Error priority and above
journalctl --since "2 hours ago"
journalctl -u ssh -n 50                  # SSH service logs
journalctl --disk-usage                  # How much journal space is used
```

### Log Rotation
Linux uses `logrotate` to prevent logs from filling the disk:

```bash
# Check logrotate config
cat /etc/logrotate.conf
ls /etc/logrotate.d/

# Manually run logrotate
sudo logrotate -f /etc/logrotate.conf
```

---

## 8. Process Management

```bash
# List all processes
ps aux

# Find a specific process
ps aux | grep nginx
pgrep nginx

# Kill a process
kill <PID>               # Graceful (SIGTERM)
kill -9 <PID>            # Forceful (SIGKILL) — last resort

# Interactive process manager
top
htop                     # Better (install: apt install htop)

# Check what a process is doing
strace -p <PID>          # System calls (requires root)
lsof -p <PID>            # Open files
```

### Process States in `ps`
| Code | State |
|---|---|
| `R` | Running or runnable |
| `S` | Sleeping (waiting for event) |
| `D` | Uninterruptible sleep (usually I/O) |
| `Z` | **Zombie** – finished but not reaped by parent |
| `T` | Stopped (by signal or debugger) |

> **Zombie processes:** Cannot be killed with `kill -9` — they're already dead. The parent process must call `wait()`. If zombies accumulate, the parent process has a bug.

---

## 9. Security Monitoring Basics

### Check Who Is Logged In
```bash
who                      # Currently logged in
w                        # What they're doing
last                     # Login history
lastb                    # Failed login attempts
```

### Check for Unauthorized Access
```bash
# Failed SSH logins (Debian/Ubuntu)
grep "Failed password" /var/log/auth.log | tail -20

# Failed SSH logins (RHEL/CentOS)
grep "Failed password" /var/log/secure | tail -20

# Top attacking IPs
grep "Failed password" /var/log/auth.log | grep -oE "from ([0-9]+\.){3}[0-9]+" | \
    awk '{print $2}' | sort | uniq -c | sort -rn | head -10
```

### Check Sudo Access
```bash
cat /etc/sudoers
getent group sudo
getent group wheel
```

### fail2ban – Automated Brute Force Protection
```bash
# Install
sudo apt install fail2ban

# Check ban status
sudo fail2ban-client status sshd

# See banned IPs
sudo fail2ban-client status sshd | grep "Banned IP"
```

---

## 10. Cloud Monitoring Context

In cloud environments (AWS/GCP/Azure), infrastructure monitoring extends beyond the OS:

| Cloud Concept | Linux Equivalent |
|---|---|
| CloudWatch (AWS) | Prometheus + Grafana |
| Cloud Monitoring (GCP) | Node Exporter + Alertmanager |
| Azure Monitor | Custom scripts + metrics agent |
| Instance metadata | `/proc/cpuinfo`, `dmidecode` |
| Auto Scaling | Load-based service management |
| Health Checks | `./scripts/health-report.sh` |

### Useful Cloud Commands on EC2
```bash
# Get instance metadata (AWS)
curl http://169.254.169.254/latest/meta-data/instance-id
curl http://169.254.169.254/latest/meta-data/instance-type
curl http://169.254.169.254/latest/meta-data/public-ipv4
curl http://169.254.169.254/latest/meta-data/placement/region
```

---

## Author

**Vatsalya Patel** – Linux Admin | Cloud Support Engineer  
GitHub: [github.com/lnvpatel](https://github.com/lnvpatel)  
LinkedIn: [linkedin.com/in/lnvpatel](https://linkedin.com/in/lnvpatel)
