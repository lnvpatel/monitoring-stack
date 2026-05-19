#!/bin/bash

# ==========================================
# System Uptime Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Displays system uptime, exact boot time,
#   load average with classification,
#   logged-in users, and recent reboot history.
#
# Usage:
#   ./uptime-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   System Uptime Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Uptime & Boot Time ────────────────────────────────────────────────────────
echo -e "${BOLD}── Uptime ──────────────────────────────────${RESET}"

UPTIME_SECONDS=$(awk '{printf "%d", $1}' /proc/uptime)
DAYS=$((UPTIME_SECONDS / 86400))
HOURS=$(( (UPTIME_SECONDS % 86400) / 3600 ))
MINUTES=$(( (UPTIME_SECONDS % 3600) / 60 ))
SECONDS_REM=$((UPTIME_SECONDS % 60))

echo -e "  Uptime        : ${BOLD}${DAYS} day(s), ${HOURS} hour(s), ${MINUTES} minute(s), ${SECONDS_REM} second(s)${RESET}"

# Boot time
BOOT_TIME_EPOCH=$(date -d "$(uptime -s 2>/dev/null)" +%s 2>/dev/null)
BOOT_TIME_STR=$(uptime -s 2>/dev/null || who -b | awk '{print $3, $4}')
echo -e "  Boot Time     : ${BOLD}${BOOT_TIME_STR}${RESET}"

# High uptime alert (> 30 days, server may need patching)
if [ "$DAYS" -gt 30 ]; then
    echo ""
    echo -e "  ${YELLOW}[INFO]${RESET} System has been up for ${DAYS} days."
    echo -e "         ${YELLOW}Consider scheduling a maintenance window for updates/reboots.${RESET}"
fi

# ── Load Averages ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Load Averages ───────────────────────────${RESET}"
LOAD_1=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
LOAD_15=$(awk '{print $3}' /proc/loadavg)
RUNNING_PROCS=$(awk -F"/" '{print $1}' /proc/loadavg | awk '{print $4}' | cut -d'/' -f1)
TOTAL_PROCS=$(awk '{print $4}' /proc/loadavg | cut -d'/' -f2)
CPU_CORES=$(nproc)

echo -e "  1  min avg : ${BOLD}${LOAD_1}${RESET}"
echo -e "  5  min avg : ${BOLD}${LOAD_5}${RESET}"
echo -e "  15 min avg : ${BOLD}${LOAD_15}${RESET}"
echo -e "  CPU Cores  : ${BOLD}${CPU_CORES}${RESET}"
echo ""

# Load classification
LOAD_X10=$(echo "$LOAD_1" | awk '{printf "%d", $1 * 10}')
CORES_X10=$((CPU_CORES * 10))

if   [ "$LOAD_X10" -gt $((CORES_X10 * 2)) ]; then
    echo -e "  ${RED}[CRITICAL]${RESET}  Load ${LOAD_1} is VERY HIGH — system is severely overloaded"
    echo -e "             Expect slow response times and possible timeouts."
elif [ "$LOAD_X10" -gt "$CORES_X10" ]; then
    echo -e "  ${RED}[WARNING]${RESET}   Load ${LOAD_1} exceeds available cores (${CPU_CORES})"
    echo -e "             System is overloaded — investigate running processes."
elif [ "$LOAD_X10" -gt $((CORES_X10 * 7 / 10)) ]; then
    echo -e "  ${YELLOW}[MODERATE]${RESET}  Load ${LOAD_1} is moderate (~$(awk "BEGIN {printf \"%.0f\", ($LOAD_X10/$CORES_X10)*100}")% of capacity)"
else
    echo -e "  ${GREEN}[  LOW  ]${RESET}   Load ${LOAD_1} is healthy ($(awk "BEGIN {printf \"%.0f\", ($LOAD_X10/$CORES_X10)*100}")% of ${CPU_CORES} cores)"
fi

# ── Logged-In Users ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Currently Logged-In Users ───────────────${RESET}"
USER_COUNT=$(who | wc -l)
if [ "$USER_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}[ OK ]${RESET} No users currently logged in (running headless)."
else
    echo -e "  ${BOLD}${USER_COUNT}${RESET} user session(s) active:"
    echo ""
    printf "  %-12s %-10s %-20s %-s\n" "USER" "TTY" "LOGIN TIME" "FROM"
    echo "  -------------------------------------------------------"
    who 2>/dev/null | while read -r user tty date time from; do
        printf "  %-12s %-10s %-20s %-s\n" "$user" "$tty" "$date $time" "$from"
    done
fi

# ── Last 5 Reboots ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Recent Reboot History (last 5) ──────────${RESET}"
if last reboot 2>/dev/null | grep -q "reboot"; then
    last reboot 2>/dev/null | grep "reboot" | head -5 | \
        while IFS= read -r line; do echo "  $line"; done
else
    echo -e "  ${YELLOW}[INFO]${RESET} No reboot history available (wtmp may not be configured)."
fi

# ── Scheduled Cron / At Jobs ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Scheduled Jobs (crontab -l) ─────────────${RESET}"
CRON_JOBS=$(crontab -l 2>/dev/null | grep -v "^#\|^$")
if [ -z "$CRON_JOBS" ]; then
    echo -e "  ${CYAN}[INFO]${RESET} No cron jobs set for current user."
else
    echo "$CRON_JOBS" | while IFS= read -r job; do
        echo "  $job"
    done
fi

# System-wide crons
if [ -d /etc/cron.d ]; then
    SYSCRON_COUNT=$(ls /etc/cron.d/ 2>/dev/null | wc -l)
    echo -e "\n  System cron jobs (/etc/cron.d/) : ${BOLD}${SYSCRON_COUNT}${RESET} file(s)"
fi

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Uptime monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"