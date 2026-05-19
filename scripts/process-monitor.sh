#!/bin/bash

# ==========================================
# Process Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Displays top CPU and memory consuming
#   processes, zombie process detection,
#   process count per user, and thread stats.
#
# Usage:
#   ./process-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Process Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Process Summary ────────────────────────────────────────────────────────────
echo -e "${BOLD}── Process Overview ────────────────────────${RESET}"
TOTAL_PROCS=$(ps aux --no-headers 2>/dev/null | wc -l)
RUNNING_PROCS=$(ps aux --no-headers 2>/dev/null | awk '$8=="R"' | wc -l)
SLEEPING_PROCS=$(ps aux --no-headers 2>/dev/null | awk '$8=="S" || $8=="D"' | wc -l)
ZOMBIE_COUNT=$(ps aux --no-headers 2>/dev/null | awk '$8=="Z"' | wc -l)
TOTAL_THREADS=$(cat /proc/sys/kernel/threads-max 2>/dev/null || echo "N/A")
CURRENT_THREADS=$(ps -eo nlwp 2>/dev/null | tail -n +2 | awk '{s+=$1} END {print s}')

echo -e "  Total Processes  : ${BOLD}${TOTAL_PROCS}${RESET}"
echo -e "  Running (R)      : ${BOLD}${RUNNING_PROCS}${RESET}"
echo -e "  Sleeping (S/D)   : ${BOLD}${SLEEPING_PROCS}${RESET}"
echo -e "  Zombie (Z)       : ${BOLD}${ZOMBIE_COUNT}${RESET}"
echo -e "  Total Threads    : ${BOLD}${CURRENT_THREADS}${RESET}  (kernel max: ${TOTAL_THREADS})"

if [ "$ZOMBIE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "  ${RED}[ALERT]${RESET} ${ZOMBIE_COUNT} zombie process(es) detected!"
    echo -e "  ${YELLOW}[INFO]${RESET}  Zombies consume PID slots. Parent process must reap them."
else
    echo ""
    echo -e "  ${GREEN}[  OK ]${RESET} No zombie processes."
fi

# ── Zombie Processes Detail ────────────────────────────────────────────────────
if [ "$ZOMBIE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${BOLD}── Zombie Process Details ──────────────────${RESET}"
    printf "  %-8s %-8s %-6s %-s\n" "PID" "PPID" "STATE" "COMMAND"
    echo "  ----------------------------------------"
    ps -eo pid,ppid,stat,comm 2>/dev/null | awk '$3 ~ /Z/ {
        printf "  %-8s %-8s %-6s %-s\n", $1, $2, $3, $4
    }'
fi

# ── Top 10 CPU Consumers ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Top 10 CPU-Consuming Processes ──────────${RESET}"
printf "  %-8s %-8s %-6s %-6s %-s\n" "PID" "USER" "%CPU" "%MEM" "COMMAND"
echo "  -------------------------------------------------------"
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -11 | tail -10 | \
    while read -r pid user cpu mem comm; do
        # Highlight high CPU
        if awk "BEGIN {exit !($cpu > 50)}"; then
            printf "  ${RED}%-8s %-8s %-6s %-6s %-s${RESET}\n" "$pid" "$user" "$cpu" "$mem" "$comm"
        elif awk "BEGIN {exit !($cpu > 20)}"; then
            printf "  ${YELLOW}%-8s %-8s %-6s %-6s %-s${RESET}\n" "$pid" "$user" "$cpu" "$mem" "$comm"
        else
            printf "  %-8s %-8s %-6s %-6s %-s\n" "$pid" "$user" "$cpu" "$mem" "$comm"
        fi
    done

# ── Top 10 Memory Consumers ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Top 10 Memory-Consuming Processes ───────${RESET}"
printf "  %-8s %-8s %-6s %-10s %-s\n" "PID" "USER" "%MEM" "RSS(KB)" "COMMAND"
echo "  -------------------------------------------------------"
ps -eo pid,user,%mem,rss,comm --sort=-%mem 2>/dev/null | head -11 | tail -10 | \
    while read -r pid user mem rss comm; do
        printf "  %-8s %-8s %-6s %-10s %-s\n" "$pid" "$user" "$mem" "$rss" "$comm"
    done

# ── Processes per User ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Process Count per User ──────────────────${RESET}"
printf "  %-20s %-10s %-10s\n" "USER" "PROCESSES" "THREADS"
echo "  ----------------------------------------"
ps -eo user,nlwp --no-headers 2>/dev/null | awk '{
    user[$1] += 1
    threads[$1] += $2
} END {
    for (u in user)
        printf "  %-20s %-10s %-10s\n", u, user[u], threads[u]
}' | sort -k2 -rn | head -15

# ── High-Thread Processes ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Processes with Most Threads (top 10) ────${RESET}"
printf "  %-8s %-8s %-10s %-s\n" "PID" "THREADS" "USER" "COMMAND"
echo "  -------------------------------------------------------"
ps -eo pid,nlwp,user,comm --sort=-nlwp 2>/dev/null | head -11 | tail -10 | \
    while read -r pid nlwp user comm; do
        printf "  %-8s %-8s %-10s %-s\n" "$pid" "$nlwp" "$user" "$comm"
    done

# ── Long-Running Processes ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Longest Running Processes (top 10) ──────${RESET}"
printf "  %-8s %-10s %-10s %-s\n" "PID" "USER" "ELAPSED" "COMMAND"
echo "  -------------------------------------------------------"
ps -eo pid,user,etime,comm --sort=-etime 2>/dev/null | head -11 | tail -10 | \
    while read -r pid user etime comm; do
        printf "  %-8s %-10s %-10s %-s\n" "$pid" "$user" "$etime" "$comm"
    done

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Process monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"

