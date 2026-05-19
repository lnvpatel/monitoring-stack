#!/bin/bash

# ==========================================
# Log Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Scans system log files for errors,
#   warnings, OOM events, and failed units.
#   Works with both syslog and journald.
#
# Usage:
#   ./log-monitor.sh
#   sudo ./log-monitor.sh    (for full log access)
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   System Log Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Determine Log Source ───────────────────────────────────────────────────────
SYSLOG=""
for f in /var/log/syslog /var/log/messages /var/log/kern.log; do
    if [ -r "$f" ]; then
        SYSLOG="$f"
        break
    fi
done

echo -e "${BOLD}── Log Sources ─────────────────────────────${RESET}"
if [ -n "$SYSLOG" ]; then
    echo -e "  ${GREEN}[ FOUND ]${RESET}  Syslog: ${BOLD}${SYSLOG}${RESET}"
else
    echo -e "  ${YELLOW}[  N/A  ]${RESET}  No readable syslog file. Using journald only."
fi

JOURNALD_OK=false
if command -v journalctl &>/dev/null; then
    journalctl -n 1 &>/dev/null && JOURNALD_OK=true
    echo -e "  ${GREEN}[ FOUND ]${RESET}  journald: ${BOLD}available${RESET}"
fi

# ── Recent Errors (last 50 lines of syslog) ────────────────────────────────────
if [ -n "$SYSLOG" ]; then
    echo ""
    echo -e "${BOLD}── Recent ERROR/CRITICAL Lines (syslog) ─────${RESET}"
    ERROR_LINES=$(grep -iE "error|critical|failed|fatal|emerg|alert|panic" "$SYSLOG" \
        2>/dev/null | tail -20)
    if [ -n "$ERROR_LINES" ]; then
        echo "$ERROR_LINES" | while IFS= read -r line; do
            echo -e "  ${RED}│${RESET} $line"
        done
    else
        echo -e "  ${GREEN}[  OK  ]${RESET}  No recent error entries in syslog."
    fi

    # ── Warning Lines ──────────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}── Recent WARNING Lines (last 10) ───────────${RESET}"
    WARN_LINES=$(grep -iE "\bwarn(ing)?\b" "$SYSLOG" 2>/dev/null | \
        grep -viE "error|critical|failed" | tail -10)
    if [ -n "$WARN_LINES" ]; then
        echo "$WARN_LINES" | while IFS= read -r line; do
            echo -e "  ${YELLOW}│${RESET} $line"
        done
    else
        echo -e "  ${GREEN}[  OK  ]${RESET}  No recent warning entries."
    fi
fi

# ── OOM (Out of Memory) Events ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── OOM (Out-of-Memory) Killer Events ────────${RESET}"
OOM_FROM_DMESG=$(dmesg 2>/dev/null | grep -i "out of memory\|oom-kill\|oom_kill" | tail -5)
OOM_FROM_SYSLOG=""
[ -n "$SYSLOG" ] && OOM_FROM_SYSLOG=$(grep -i "out of memory\|oom-kill" "$SYSLOG" 2>/dev/null | tail -5)

OOM_ALL="${OOM_FROM_DMESG}${OOM_FROM_SYSLOG}"
if [ -z "$OOM_ALL" ]; then
    echo -e "  ${GREEN}[  OK  ]${RESET}  No OOM events detected."
else
    echo -e "  ${RED}[ALERT]${RESET}  OOM killer events found:"
    echo "$OOM_ALL" | sort -u | while IFS= read -r line; do
        echo -e "  ${RED}│${RESET} $line"
    done
fi

# ── Authentication Failures ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Authentication Failures ─────────────────${RESET}"
AUTH_LOG=""
for f in /var/log/auth.log /var/log/secure; do
    [ -r "$f" ] && AUTH_LOG="$f" && break
done

if [ -n "$AUTH_LOG" ]; then
    FAIL_COUNT=$(grep -c "Failed password\|authentication failure\|Invalid user" \
        "$AUTH_LOG" 2>/dev/null || echo 0)
    FAIL_RECENT=$(grep -E "Failed password|Invalid user" "$AUTH_LOG" 2>/dev/null | tail -10)

    echo -e "  Total auth failures in log : ${BOLD}${FAIL_COUNT}${RESET}"
    echo ""
    if [ -n "$FAIL_RECENT" ]; then
        echo -e "  ${YELLOW}Recent failed logins:${RESET}"
        echo "$FAIL_RECENT" | while IFS= read -r line; do
            echo -e "  ${YELLOW}│${RESET} $line"
        done
    fi

    # Top attacking IPs
    echo ""
    echo -e "${BOLD}── Top Source IPs for Failed SSH ────────────${RESET}"
    grep "Failed password" "$AUTH_LOG" 2>/dev/null | \
        grep -oE "from ([0-9]+\.){3}[0-9]+" | awk '{print $2}' | \
        sort | uniq -c | sort -rn | head -10 | \
        while read -r count ip; do
            printf "  %-6s attempts  from  %s\n" "$count" "$ip"
        done
    echo -e "  ${CYAN}[TIP]${RESET} Use fail2ban to automatically block repeat offenders."
else
    echo -e "  ${YELLOW}[INFO]${RESET} Auth log not readable. Run with sudo for SSH failure data."
fi

# ── Failed Systemd Units ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Failed systemd Units ────────────────────${RESET}"
FAILED_UNITS=$(systemctl list-units --state=failed --no-legend 2>/dev/null)
if [ -z "$FAILED_UNITS" ]; then
    echo -e "  ${GREEN}[  OK  ]${RESET}  No failed systemd units."
else
    echo -e "  ${RED}[ALERT]${RESET}  Failed units detected:"
    echo "$FAILED_UNITS" | while IFS= read -r line; do
        echo -e "  ${RED}│${RESET} $line"
    done
    echo -e "\n  ${YELLOW}[TIP]${RESET}  Use: journalctl -xe   to view detailed error logs"
fi

# ── Journald Error Summary (last hour) ────────────────────────────────────────
if $JOURNALD_OK; then
    echo ""
    echo -e "${BOLD}── journald Errors (last 1 hour) ───────────${RESET}"
    JOURNAL_ERRORS=$(journalctl --since "1 hour ago" -p err -n 20 --no-pager 2>/dev/null)
    if [ -z "$JOURNAL_ERRORS" ]; then
        echo -e "  ${GREEN}[  OK  ]${RESET}  No error-level journal entries in the last hour."
    else
        echo "$JOURNAL_ERRORS" | head -20 | while IFS= read -r line; do
            echo -e "  ${RED}│${RESET} $line"
        done
    fi

    # ── Disk I/O Errors ────────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}── Disk / Hardware Errors (journald) ────────${RESET}"
    HW_ERRORS=$(journalctl -p err --no-pager -n 50 2>/dev/null | \
        grep -iE "I/O error|disk error|bad sector|hardware error|ata|nvme|scsi" | tail -10)
    if [ -z "$HW_ERRORS" ]; then
        echo -e "  ${GREEN}[  OK  ]${RESET}  No disk or hardware errors in journal."
    else
        echo -e "  ${RED}[ALERT]${RESET}  Hardware/disk errors found:"
        echo "$HW_ERRORS" | while IFS= read -r line; do
            echo -e "  ${RED}│${RESET} $line"
        done
    fi
fi

# ── Kernel Ring Buffer (dmesg) ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Kernel Errors (dmesg – last 10) ─────────${RESET}"
DMESG_ERRORS=$(dmesg 2>/dev/null | grep -iE "\berr(or)?\b|warn(ing)?|crit|fail|panic" | \
    grep -v "perf\|firmware\|microcode" | tail -10)
if [ -z "$DMESG_ERRORS" ]; then
    echo -e "  ${GREEN}[  OK  ]${RESET}  No critical kernel messages."
else
    echo "$DMESG_ERRORS" | while IFS= read -r line; do
        echo -e "  ${RED}│${RESET} $line"
    done
fi

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Log monitoring completed."
echo -e "  ${CYAN}TIP:${RESET} Run with 'sudo' for full log access."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
