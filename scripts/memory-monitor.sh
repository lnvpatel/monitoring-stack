#!/bin/bash

# ==========================================
# Memory Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Displays detailed RAM and swap usage,
#   memory pressure indicators, and the
#   top 10 memory-consuming processes.
#
# Usage:
#   ./memory-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"
MEMORY_THRESHOLD=80
SWAP_THRESHOLD=50

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Memory Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── RAM Summary ───────────────────────────────────────────────────────────────
echo -e "${BOLD}── RAM ─────────────────────────────────────${RESET}"
free -h | grep -v "^$"
echo ""

MEM_TOTAL=$(free | awk '/Mem:/ {print $2}')
MEM_USED=$(free  | awk '/Mem:/ {print $3}')
MEM_AVAIL=$(free | awk '/Mem:/ {print $7}')
MEM_PCT=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED/$MEM_TOTAL)*100}")
MEM_PCT_INT=$(echo "$MEM_PCT" | cut -d. -f1)
MEM_AVAIL_PCT=$(awk "BEGIN {printf \"%.1f\", ($MEM_AVAIL/$MEM_TOTAL)*100}")
MEM_TOTAL_H=$(free -h | awk '/Mem:/ {print $2}')
MEM_USED_H=$(free -h  | awk '/Mem:/ {print $3}')
MEM_AVAIL_H=$(free -h | awk '/Mem:/ {print $7}')

echo -e "  Total     : ${BOLD}${MEM_TOTAL_H}${RESET}"
echo -e "  Used      : ${BOLD}${MEM_USED_H}${RESET}  (${MEM_PCT}%)"
echo -e "  Available : ${BOLD}${MEM_AVAIL_H}${RESET}  (${MEM_AVAIL_PCT}%)"
echo ""

if [ "$MEM_PCT_INT" -ge "$MEMORY_THRESHOLD" ]; then
    echo -e "  ${RED}[CRITICAL]${RESET} Memory usage is HIGH: ${MEM_PCT}%"
elif [ "$MEM_PCT_INT" -ge $((MEMORY_THRESHOLD - 10)) ]; then
    echo -e "  ${YELLOW}[WARNING]${RESET}  Memory usage is elevated: ${MEM_PCT}%"
else
    echo -e "  ${GREEN}[  OK   ]${RESET}  Memory usage is normal: ${MEM_PCT}%"
fi

# ── Swap Summary ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Swap ────────────────────────────────────${RESET}"
SWAP_TOTAL=$(free | awk '/Swap:/ {print $2}')

if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo -e "  No swap partition configured."
else
    SWAP_USED=$(free | awk '/Swap:/ {print $3}')
    SWAP_PCT=$(awk "BEGIN {printf \"%.1f\", ($SWAP_USED/$SWAP_TOTAL)*100}")
    SWAP_PCT_INT=$(echo "$SWAP_PCT" | cut -d. -f1)
    SWAP_TOTAL_H=$(free -h | awk '/Swap:/ {print $2}')
    SWAP_USED_H=$(free -h  | awk '/Swap:/ {print $3}')
    SWAP_FREE_H=$(free -h  | awk '/Swap:/ {print $4}')

    echo -e "  Total : ${BOLD}${SWAP_TOTAL_H}${RESET}  |  Used : ${BOLD}${SWAP_USED_H}${RESET} (${SWAP_PCT}%)  |  Free : ${BOLD}${SWAP_FREE_H}${RESET}"
    echo ""
    if [ "$SWAP_PCT_INT" -ge "$SWAP_THRESHOLD" ]; then
        echo -e "  ${RED}[WARNING]${RESET} Heavy swap usage (${SWAP_PCT}%) — possible memory pressure"
    elif [ "$SWAP_PCT_INT" -gt 0 ]; then
        echo -e "  ${YELLOW}[INFO]${RESET}    Swap in use: ${SWAP_PCT}%"
    else
        echo -e "  ${GREEN}[  OK ]${RESET}    Swap is not in use"
    fi
fi

# ── Memory Pressure ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Memory Pressure Indicators ──────────────${RESET}"
to_mb() { echo $((${1:-0} / 1024)); }
CACHED=$(awk '/^Cached:/ {print $2}' /proc/meminfo)
BUFFERS=$(awk '/^Buffers:/ {print $2}' /proc/meminfo)
SLAB=$(awk '/^Slab:/ {print $2}' /proc/meminfo)
DIRTY=$(awk '/^Dirty:/ {print $2}' /proc/meminfo)
echo -e "  Cached  : $(to_mb $CACHED) MB  (filesystem cache – reclaimable)"
echo -e "  Buffers : $(to_mb $BUFFERS) MB  (I/O buffer cache)"
echo -e "  Slab    : $(to_mb $SLAB) MB  (kernel data structures)"
echo -e "  Dirty   : $(to_mb $DIRTY) MB  (pending disk writes)"

OOM_COUNT=$(dmesg 2>/dev/null | grep -c "Out of memory" 2>/dev/null || echo 0)
echo ""
if [ "$OOM_COUNT" -gt 0 ]; then
    echo -e "  ${RED}[ALERT]${RESET} OOM killer triggered ${OOM_COUNT} time(s) since boot!"
else
    echo -e "  ${GREEN}[  OK ]${RESET} No OOM killer events since boot"
fi

# ── Top 10 Memory Consuming Processes ─────────────────────────────────────────
echo ""
echo -e "${BOLD}── Top 10 Memory-Consuming Processes ───────${RESET}"
printf "  %-8s %-6s %-6s %-s\n" "PID" "%MEM" "%CPU" "COMMAND"
echo "  ----------------------------------------"
ps -eo pid,%mem,%cpu,comm --sort=-%mem 2>/dev/null | head -11 | tail -10 | \
    while read -r pid mem cpu comm; do
        printf "  %-8s %-6s %-6s %-s\n" "$pid" "$mem" "$cpu" "$comm"
    done

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Memory monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
