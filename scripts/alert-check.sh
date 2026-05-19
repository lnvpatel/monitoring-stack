#!/bin/bash

# ==========================================
# Infrastructure Alert Check Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Monitors CPU, memory, swap, disk usage,
#   and load averages against configurable
#   thresholds. Outputs color-coded alerts
#   and appends results to a log file.
#
# Usage:
#   ./alert-check.sh
#   ./alert-check.sh --no-color      (plain output for cron/email)
#
# Cron Example (run every 15 minutes):
#   */15 * * * * /path/to/alert-check.sh --no-color >> /var/log/alerts.log 2>&1
# ==========================================

# ── Thresholds (edit to suit your environment) ────────────────────────────────
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
SWAP_THRESHOLD=60
DISK_THRESHOLD=80
LOAD_THRESHOLD=2        # load average per core; 1.0 = 100% one core busy

# ── Log file ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/alert-check.log"
mkdir -p "$LOG_DIR"

# ── Color support ─────────────────────────────────────────────────────────────
USE_COLOR=true
if [[ "$1" == "--no-color" ]] || ! command -v tput &>/dev/null || [[ "$(tput colors 2>/dev/null)" -lt 8 ]]; then
    USE_COLOR=false
fi

RED=""   YELLOW=""   GREEN=""   CYAN=""   BOLD=""   RESET=""
if $USE_COLOR; then
    RED="\e[0;31m"   YELLOW="\e[0;33m"   GREEN="\e[0;32m"
    CYAN="\e[0;36m"  BOLD="\e[1m"        RESET="\e[0m"
fi

# ── Helper functions ──────────────────────────────────────────────────────────
ALERT_COUNT=0

print_header() {
    echo -e "${BOLD}${CYAN}==========================================${RESET}"
    echo -e "${BOLD}${CYAN}   Infrastructure Alert Report${RESET}"
    echo -e "${BOLD}${CYAN}==========================================${RESET}"
    echo -e "  Hostname : $(hostname)"
    echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
}

status_ok()       { echo -e "  ${GREEN}[  OK  ]${RESET}  $1"; }
status_warning()  { echo -e "  ${YELLOW}[ WARN ]${RESET}  $1"; ALERT_COUNT=$((ALERT_COUNT + 1)); }
status_critical() { echo -e "  ${RED}[ CRIT ]${RESET}  $1"; ALERT_COUNT=$((ALERT_COUNT + 1)); }
section()         { echo -e "\n${BOLD}── $1 ──────────────────────────────────${RESET}"; }

# ── Main ──────────────────────────────────────────────────────────────────────
{   # Everything inside {} is also written to log file

print_header

# ── CPU Usage ─────────────────────────────────────────────────────────────────
section "CPU"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
echo -e "  Usage : ${BOLD}${CPU_USAGE}%${RESET}  (threshold: ${CPU_THRESHOLD}%)"

if   [ "$CPU_USAGE" -ge "$CPU_THRESHOLD" ]; then
    status_critical "CPU usage is CRITICAL: ${CPU_USAGE}%"
elif [ "$CPU_USAGE" -ge $((CPU_THRESHOLD - 10)) ]; then
    status_warning  "CPU usage is elevated: ${CPU_USAGE}%"
else
    status_ok "CPU usage is normal: ${CPU_USAGE}%"
fi

# ── Load Average ──────────────────────────────────────────────────────────────
section "Load Average"
LOAD_1=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
LOAD_15=$(awk '{print $3}' /proc/loadavg)
CPU_CORES=$(nproc)
echo -e "  1m: ${BOLD}${LOAD_1}${RESET}   5m: ${BOLD}${LOAD_5}${RESET}   15m: ${BOLD}${LOAD_15}${RESET}   (${CPU_CORES} cores)"

# Compare load against cores (integer math: multiply by 10 for one decimal place)
LOAD_1_INT=$(echo "$LOAD_1" | awk '{printf "%d", $1 * 10}')
CORE_THRESH=$((LOAD_THRESHOLD * CPU_CORES * 10))

if [ "$LOAD_1_INT" -gt "$CORE_THRESH" ]; then
    status_critical "Load average (1m) is high: ${LOAD_1}"
else
    status_ok "Load average is normal: ${LOAD_1}"
fi

# ── Memory Usage ──────────────────────────────────────────────────────────────
section "Memory (RAM)"
MEMORY_USAGE=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
MEM_USED=$(free -h | awk '/Mem:/ {print $3}')
MEM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
echo -e "  Used  : ${BOLD}${MEM_USED} / ${MEM_TOTAL}${RESET}  (${MEMORY_USAGE}%  threshold: ${MEMORY_THRESHOLD}%)"

if   [ "$MEMORY_USAGE" -ge "$MEMORY_THRESHOLD" ]; then
    status_critical "Memory usage is CRITICAL: ${MEMORY_USAGE}%"
elif [ "$MEMORY_USAGE" -ge $((MEMORY_THRESHOLD - 10)) ]; then
    status_warning  "Memory usage is elevated: ${MEMORY_USAGE}%"
else
    status_ok "Memory usage is normal: ${MEMORY_USAGE}%"
fi

# ── Swap Usage ────────────────────────────────────────────────────────────────
section "Swap"
SWAP_TOTAL=$(free | awk '/Swap:/ {print $2}')
if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo -e "  No swap configured."
else
    SWAP_USAGE=$(free | awk '/Swap:/ {printf("%.0f"), $3/$2 * 100}')
    SWAP_USED=$(free -h | awk '/Swap:/ {print $3}')
    SWAP_TOTAL_H=$(free -h | awk '/Swap:/ {print $2}')
    echo -e "  Used  : ${BOLD}${SWAP_USED} / ${SWAP_TOTAL_H}${RESET}  (${SWAP_USAGE}%  threshold: ${SWAP_THRESHOLD}%)"

    if   [ "$SWAP_USAGE" -ge "$SWAP_THRESHOLD" ]; then
        status_critical "Swap usage is HIGH: ${SWAP_USAGE}% — possible memory pressure"
    elif [ "$SWAP_USAGE" -gt 0 ]; then
        status_warning  "Swap in use: ${SWAP_USAGE}%"
    else
        status_ok "Swap is not in use"
    fi
fi

# ── Disk Usage (all mounted local filesystems) ────────────────────────────────
section "Disk"
echo -e "  Checking all mounted filesystems (threshold: ${DISK_THRESHOLD}%):\n"
DISK_ALERT=0
while IFS= read -r line; do
    USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo "$line"  | awk '{print $6}')
    USED=$(echo "$line"   | awk '{print $3}')
    SIZE=$(echo "$line"   | awk '{print $2}')
    if   [ "$USAGE" -ge "$DISK_THRESHOLD" ]; then
        echo -e "  ${RED}[CRIT]${RESET}  ${MOUNT}  →  ${USAGE}%  (${USED} / ${SIZE})"
        ALERT_COUNT=$((ALERT_COUNT + 1)); DISK_ALERT=1
    elif [ "$USAGE" -ge $((DISK_THRESHOLD - 10)) ]; then
        echo -e "  ${YELLOW}[WARN]${RESET}  ${MOUNT}  →  ${USAGE}%  (${USED} / ${SIZE})"
        ALERT_COUNT=$((ALERT_COUNT + 1)); DISK_ALERT=1
    else
        echo -e "  ${GREEN}[ OK ]${RESET}  ${MOUNT}  →  ${USAGE}%  (${USED} / ${SIZE})"
    fi
done < <(df -hx tmpfs -x devtmpfs -x squashfs --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2)

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
if [ "$ALERT_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✔  All systems normal — no alerts.${RESET}"
else
    echo -e "  ${RED}${BOLD}✘  ${ALERT_COUNT} alert(s) detected. Review above output.${RESET}"
fi
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo ""

# ── Email alert (optional – configure SMTP first) ─────────────────────────────
# Uncomment and configure to send email when alerts are triggered:
#
# ALERT_EMAIL="youremail@example.com"
# if [ "$ALERT_COUNT" -gt 0 ]; then
#     echo "Alert: $ALERT_COUNT issue(s) detected on $(hostname) at $(date)" \
#         | mail -s "[ALERT] Infrastructure Warning – $(hostname)" "$ALERT_EMAIL"
# fi

} | tee -a "$LOG_FILE"