#!/bin/bash

# ==========================================
# System Health Report Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Generates a comprehensive infrastructure
#   health summary including OS, kernel,
#   CPU, memory, disk, network, and services.
#   Designed as a one-stop dashboard view.
#
# Usage:
#   ./health-report.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

# ── Helper ─────────────────────────────────────────────────────────────────────
section() { echo -e "\n${BOLD}${CYAN}── $1 ──────────────────────────────────${RESET}"; }
ok()      { echo -e "  ${GREEN}[  OK  ]${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}[ WARN ]${RESET}  $*"; }
info()    { echo -e "  ${CYAN}[ INFO ]${RESET}  $*"; }
crit()    { echo -e "  ${RED}[ CRIT ]${RESET}  $*"; }

echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     Infrastructure Health Report         ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# ── System Identity ────────────────────────────────────────────────────────────
section "System Identity"
echo -e "  Hostname    : ${BOLD}$(hostname -f 2>/dev/null || hostname)${RESET}"
echo -e "  IP Address  : ${BOLD}$(hostname -I 2>/dev/null | awk '{print $1}')${RESET}"
echo -e "  Date / Time : ${BOLD}$(date '+%A, %d %B %Y  %H:%M:%S %Z')${RESET}"

# ── Operating System ───────────────────────────────────────────────────────────
section "Operating System"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "  OS Name     : ${BOLD}${PRETTY_NAME}${RESET}"
    echo -e "  OS Version  : ${BOLD}${VERSION_ID:-N/A}${RESET}"
    echo -e "  OS Family   : ${BOLD}${ID_LIKE:-${ID}}${RESET}"
fi
echo -e "  Kernel      : ${BOLD}$(uname -r)${RESET}"
echo -e "  Architecture: ${BOLD}$(uname -m)${RESET}"

# Check for pending updates (Debian/Ubuntu)
if command -v apt-get &>/dev/null; then
    UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo 0)
    if [ "$UPDATES" -gt 0 ]; then
        warn "${UPDATES} pending package update(s) available"
    else
        ok "System is up to date"
    fi
fi

# ── Hardware Summary ───────────────────────────────────────────────────────────
section "Hardware"
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
CPU_CORES=$(nproc)
CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo)
MEM_TOTAL_H=$(free -h | awk '/Mem:/ {print $2}')
SWAP_TOTAL_H=$(free -h | awk '/Swap:/ {print $2}')

echo -e "  CPU Model   : ${BOLD}${CPU_MODEL}${RESET}"
echo -e "  CPU Cores   : ${BOLD}${CPU_CORES} physical  /  ${CPU_THREADS} logical threads${RESET}"
echo -e "  RAM         : ${BOLD}${MEM_TOTAL_H}${RESET}"
echo -e "  Swap        : ${BOLD}${SWAP_TOTAL_H}${RESET}"

# ── Current Load & Uptime ──────────────────────────────────────────────────────
section "Uptime & Load"
UPTIME_PRETTY=$(uptime -p 2>/dev/null || uptime)
LOAD_1=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
LOAD_15=$(awk '{print $3}' /proc/loadavg)
BOOT_TIME=$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null)

echo -e "  Uptime      : ${BOLD}${UPTIME_PRETTY}${RESET}"
echo -e "  Boot Time   : ${BOLD}${BOOT_TIME}${RESET}"
echo -e "  Load Avg    : ${BOLD}${LOAD_1}${RESET} (1m)  ${BOLD}${LOAD_5}${RESET} (5m)  ${BOLD}${LOAD_15}${RESET} (15m)"

LOAD_INT=$(echo "$LOAD_1" | awk '{printf "%d", $1 * 10}')
CORE_LIMIT=$((CPU_CORES * 10))
if [ "$LOAD_INT" -gt "$((CORE_LIMIT * 2))" ]; then
    crit "Load is VERY HIGH relative to CPU cores"
elif [ "$LOAD_INT" -gt "$CORE_LIMIT" ]; then
    warn "Load exceeds available CPU cores"
else
    ok "Load average is within normal range"
fi

# ── CPU & Memory Status ────────────────────────────────────────────────────────
section "CPU & Memory"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo 0)
MEM_PCT=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
MEM_USED_H=$(free -h | awk '/Mem:/ {print $3}')

echo -e "  CPU Usage   : ${BOLD}${CPU_USAGE}%${RESET}"
echo -e "  Memory Used : ${BOLD}${MEM_USED_H} / ${MEM_TOTAL_H}${RESET}  (${MEM_PCT}%)"

[ "$CPU_USAGE" -ge 80 ] && crit "High CPU usage: ${CPU_USAGE}%"   || ok "CPU is healthy: ${CPU_USAGE}%"
[ "$MEM_PCT"   -ge 80 ] && crit "High Memory: ${MEM_PCT}%"        || ok "Memory is healthy: ${MEM_PCT}%"

# ── Disk Status ────────────────────────────────────────────────────────────────
section "Disk Usage"
DISK_ALERT=0
while IFS= read -r line; do
    PCT=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo "$line" | awk '{print $6}')
    USED=$(echo "$line" | awk '{print $3}')
    SIZE=$(echo "$line" | awk '{print $2}')
    if [ "$PCT" -ge 80 ]; then
        crit "Disk ${MOUNT}: ${PCT}% used (${USED} / ${SIZE})"
        DISK_ALERT=1
    elif [ "$PCT" -ge 65 ]; then
        warn "Disk ${MOUNT}: ${PCT}% used (${USED} / ${SIZE})"
        DISK_ALERT=1
    else
        ok "Disk ${MOUNT}: ${PCT}% used (${USED} / ${SIZE})"
    fi
done < <(df -hx tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2)

# ── Network Interfaces ────────────────────────────────────────────────────────
section "Network Interfaces"
ip -brief address 2>/dev/null | while read -r iface state addr; do
    if [[ "$state" == "UP" ]]; then
        echo -e "  ${GREEN}[UP]${RESET}   ${BOLD}${iface}${RESET}  →  ${addr}"
    else
        echo -e "  ${RED}[DOWN]${RESET} ${BOLD}${iface}${RESET}"
    fi
done

DEFAULT_GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
echo -e "\n  Default Gateway : ${BOLD}${DEFAULT_GW:-N/A}${RESET}"

# Internet connectivity
if curl -fs --max-time 3 https://8.8.8.8 &>/dev/null || ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    ok "Internet connectivity: REACHABLE"
else
    warn "Internet connectivity: NOT REACHABLE"
fi

# ── Service Health ─────────────────────────────────────────────────────────────
section "Critical Services"
CRITICAL_SERVICES=("ssh" "cron" "rsyslog" "ufw" "fail2ban" "nginx" "apache2" "docker")
for svc in "${CRITICAL_SERVICES[@]}"; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            ok "${svc}: RUNNING"
        elif systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "enabled"; then
            warn "${svc}: ENABLED but NOT RUNNING"
        fi
    fi
done

# Count all running services
RUNNING_COUNT=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "running" || echo "N/A")
FAILED_COUNT=$(systemctl list-units --type=service --state=failed 2>/dev/null | grep -c "failed" || echo 0)
echo ""
info "Total running services : ${RUNNING_COUNT}"
[ "$FAILED_COUNT" -gt 0 ] && crit "${FAILED_COUNT} service(s) in failed state! Run: systemctl --failed" \
    || ok "No failed services"

# ── Security Quick Check ───────────────────────────────────────────────────────
section "Security Snapshot"
# Root logins
ROOT_LOGINS=$(last root 2>/dev/null | grep -v "wtmp" | head -3)
LOGGED_USERS=$(who | wc -l)
FAILED_SSH=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l || echo "N/A")

echo -e "  Logged-in users     : ${BOLD}${LOGGED_USERS}${RESET}"
echo -e "  Failed SSH attempts : ${BOLD}${FAILED_SSH}${RESET}"
[ "$FAILED_SSH" != "N/A" ] && [ "$FAILED_SSH" -gt 50 ] && \
    warn "High number of failed SSH logins: ${FAILED_SSH}" || \
    info "Failed SSH count: ${FAILED_SSH}"

LAST_REBOOT=$(last reboot 2>/dev/null | head -1 | awk '{print $5, $6, $7, $8}')
echo -e "  Last reboot         : ${BOLD}${LAST_REBOOT}${RESET}"

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║    Health report completed               ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"