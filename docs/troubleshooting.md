# Troubleshooting Guide – Monitoring Stack

> Practical troubleshooting steps for common Linux infrastructure issues. Each section covers symptoms, causes, diagnosis commands, and fixes.

---

## Quick Reference: Common Linux Admin Commands

```bash
# System overview
top                         # Interactive process/CPU/memory viewer
htop                        # Better top (sudo apt install htop)
uptime                      # Load averages + uptime
uname -a                    # Kernel and OS info

# Disk
df -h                       # Disk usage (human-readable)
df -i                       # Inode usage
du -sh /var/* | sort -rh    # Disk usage by directory
lsblk                       # Block devices

# Memory
free -h                     # RAM and swap
cat /proc/meminfo           # Detailed memory stats
vmstat 1 5                  # Memory + CPU + I/O every 1s, 5 times

# Processes
ps aux --sort=-%cpu         # Processes sorted by CPU
ps aux --sort=-%mem         # Processes sorted by memory
kill -9 <PID>               # Force kill a process
pgrep -l nginx              # Find process by name

# Network
ip addr show                # IP addresses
ip route show               # Routing table
ss -tulnp                   # Listening ports + process names
netstat -tulnp              # Alternative to ss
ping -c 4 8.8.8.8           # Connectivity test
curl -Is https://google.com # HTTP test

# Services
systemctl status <service>  # Service status
systemctl restart <service> # Restart service
journalctl -u <service>     # Service logs
journalctl -xe              # Recent system errors

# Logs
tail -f /var/log/syslog     # Live log stream
grep "error" /var/log/syslog | tail -30
dmesg | tail -30            # Kernel messages
```

---

## 1. High CPU Usage

### Symptoms
- System feels slow or unresponsive
- `top` shows CPU at 90%+
- Load average is much higher than core count

### Diagnosis
```bash
# Find which process is using most CPU
top -bn1 | head -20
ps aux --sort=-%cpu | head -10

# Check load average vs cores
uptime
nproc

# Check for runaway processes
ps aux | awk '$3 > 50 {print}'
```

### Fixes
```bash
# Gracefully stop a high-CPU process
kill <PID>

# Force kill if it doesn't respond
kill -9 <PID>

# Reduce priority of a process (nice value -20 to 19, higher = lower priority)
renice +10 <PID>

# If a service is looping, restart it
sudo systemctl restart <service-name>
```

---

## 2. High Memory Usage / Out of Memory

### Symptoms
- `free -h` shows very low `available` memory
- Swap is heavily used
- Applications crash unexpectedly
- `dmesg` shows "Out of memory: Kill process"

### Diagnosis
```bash
# Check available memory
free -h

# Find memory hogs
ps aux --sort=-%mem | head -10

# Check OOM killer activity
dmesg | grep -i "out of memory"
dmesg | grep "oom_kill"

# Check swap usage
swapon -s
free -h | grep Swap
```

### Fixes
```bash
# Drop page cache (safe to do on live systems)
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

# Kill specific memory-hungry process
kill <PID>

# If swap is full and system is frozen, OOM killer will act
# Prevent OOM: add more swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent (add to /etc/fstab)
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 3. Disk Full

### Symptoms
- `df -h` shows 100% on a filesystem
- Error: `No space left on device`
- Logs stop rotating, databases won't write

### Diagnosis
```bash
# Check which filesystem is full
df -h

# Find the largest directories
du -sh /* 2>/dev/null | sort -rh | head -10
du -sh /var/* | sort -rh | head -10

# Find large files
find /var /tmp /home -type f -size +100M 2>/dev/null | xargs ls -lh

# Check for deleted files still held open (common gotcha!)
sudo lsof | grep deleted | head -20

# Check inode usage (different from disk space!)
df -i
```

### Fixes
```bash
# Remove old logs
sudo journalctl --vacuum-size=500M    # Keep only 500MB of journal
sudo journalctl --vacuum-time=7d      # Keep only 7 days of journal

# Clear apt cache (Debian/Ubuntu)
sudo apt clean
sudo apt autoremove

# Remove old kernels
sudo apt autoremove --purge

# Find and delete core dumps
find / -name "core" -type f 2>/dev/null
sudo rm /var/crash/*

# Truncate a log file (don't delete, the process may still hold it open)
sudo truncate -s 0 /var/log/large-logfile.log

# If deleted-file space not released: restart the process holding it
sudo systemctl restart <service>
```

---

## 4. Service Won't Start

### Symptoms
- `systemctl status <service>` shows `failed`
- Application not responding on its port

### Diagnosis
```bash
# Get detailed status
systemctl status nginx

# View the last 50 log lines
journalctl -u nginx -n 50 --no-pager

# View logs since last boot
journalctl -u nginx -b

# Check if port is already in use
ss -tulnp | grep :80
sudo lsof -i :80
```

### Fixes
```bash
# Try restarting
sudo systemctl restart nginx

# Check the config file for syntax errors (nginx example)
sudo nginx -t

# Check if another process is using the port
sudo fuser -k 80/tcp          # Kill whatever is using port 80

# Check file permissions (common issue)
ls -la /etc/nginx/
sudo chown -R www-data:www-data /var/www/html

# Reload systemd if unit file changed
sudo systemctl daemon-reload
sudo systemctl restart nginx
```

---

## 5. Cannot Connect via SSH

### Symptoms
- SSH connection refused or times out
- `ssh user@server` hangs

### Diagnosis
```bash
# On the server, check SSH service
sudo systemctl status ssh    # (or sshd on some distros)

# Check which port SSH is listening on
sudo ss -tulnp | grep ssh

# Check firewall rules
sudo ufw status
sudo iptables -L -n | grep 22

# Check SSH config
sudo sshd -t           # Test SSH config for errors
cat /etc/ssh/sshd_config | grep -v "^#\|^$"
```

### Fixes
```bash
# Start SSH if it's stopped
sudo systemctl start ssh

# Restart SSH (keep current sessions open)
sudo systemctl reload ssh

# Allow SSH through firewall (ufw)
sudo ufw allow ssh
sudo ufw allow 22/tcp

# Check if fail2ban banned you
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip <your-ip>

# If locked out entirely: use cloud console (AWS console, GCP SSH in browser)
```

---

## 6. Network Connectivity Issues

### Symptoms
- Cannot reach the internet
- DNS resolution fails
- Services can't communicate

### Diagnosis
```bash
# Step 1: Is the interface up?
ip -brief address
ip link show

# Step 2: Do we have a default route?
ip route show

# Step 3: Can we reach the gateway?
DEFAULT_GW=$(ip route show default | awk '{print $3}')
ping -c 3 $DEFAULT_GW

# Step 4: Can we reach internet by IP? (bypasses DNS)
ping -c 3 8.8.8.8

# Step 5: Can we resolve DNS?
nslookup google.com
dig google.com @8.8.8.8

# Check DNS config
cat /etc/resolv.conf
```

### Fixes
```bash
# Bring interface up
sudo ip link set eth0 up

# Set DNS server manually (temporary)
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Restart network (systemd-networkd)
sudo systemctl restart systemd-networkd

# Restart network (NetworkManager)
sudo systemctl restart NetworkManager

# Flush and renew IP (DHCP)
sudo dhclient -r eth0
sudo dhclient eth0
```

---

## 7. High Disk I/O (System Feels Slow Despite Low CPU)

### Symptoms
- `top` shows low CPU but `wa` (I/O wait) is high
- System is sluggish
- Commands hang

### Diagnosis
```bash
# Check I/O wait
top
# Look at: Cpu(s): 5.0 us,  1.0 sy,  0.0 ni, 50.0 id, 43.0 wa

# Install iotop for per-process I/O
sudo apt install iotop
sudo iotop -o              # Show only processes doing I/O

# iostat shows disk utilization
iostat -x 1 5              # Check %util column (>80% = saturated)

# vmstat shows I/O stats
vmstat 1 10                # bi = blocks in, bo = blocks out

# Check which process has files open
sudo lsof | grep -E "REG.*sda"
```

### Fixes
```bash
# If a process is doing excessive I/O, identify and throttle or restart it
sudo systemctl restart <service>

# Use ionice to lower I/O priority
sudo ionice -c 3 -p <PID>    # Idle class – only runs when disk is free

# Check for large write jobs (backup, compression running in background)
ps aux | grep -E "tar|cp|rsync|dd"
```

---

## 8. Zombie Processes

### Symptoms
- `ps aux` shows processes with state `Z`
- Can't kill them with `kill -9`

### Explanation
Zombie processes are already dead — they're waiting for their parent to call `wait()` to collect exit status. Killing the parent usually cleans them up.

### Diagnosis
```bash
# Find zombies and their parents
ps aux | awk '$8=="Z" {print}'
ps -eo pid,ppid,stat,comm | awk '$3 ~ /Z/'
```

### Fix
```bash
# Find parent PID (PPID) of the zombie
ps -o ppid= -p <zombie_PID>

# Signal the parent to reap its children
kill -SIGCHLD <parent_PID>

# If that doesn't work, restart the parent service
sudo systemctl restart <parent-service>

# Last resort: reboot (if many zombies are consuming PIDs)
```

---

## 9. How to Read `ss` Output

```bash
ss -tulnp
```

| Column | Meaning |
|---|---|
| `Netid` | Protocol: `tcp`, `udp`, `unix` |
| `State` | `LISTEN`, `ESTAB`, `CLOSE-WAIT` |
| `Local Address:Port` | What the server binds to |
| `Peer Address:Port` | Remote connection (for established) |
| `Process` | Process name and PID |

**Common ports to know:**

| Port | Service |
|---|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 8080 | Alternative HTTP / app servers |
| 9090 | Prometheus |
| 3000 | Grafana |
| 9100 | Node Exporter |

---

## 10. Using `journalctl` for Service Debugging

```bash
# View logs for a specific service
journalctl -u nginx

# Last 50 lines (most useful for quick debug)
journalctl -u nginx -n 50 --no-pager

# Live log streaming (like tail -f)
journalctl -u nginx -f

# Since last reboot
journalctl -u nginx -b

# Time range
journalctl -u nginx --since "2026-01-01 08:00" --until "2026-01-01 10:00"

# Priority levels (0=emerg, 1=alert, 2=crit, 3=err, 4=warning, 5=notice)
journalctl -p err                     # Error and above
journalctl -p warning --since today   # Warnings today

# Cross-service error view (most important for general debugging)
journalctl -xe                        # Most recent errors with context
```

---

## Author

**Vatsalya Patel** – Linux Admin | Cloud Support Engineer  
GitHub: [github.com/lnvpatel](https://github.com/lnvpatel)  
LinkedIn: [linkedin.com/in/lnvpatel](https://linkedin.com/in/lnvpatel)
