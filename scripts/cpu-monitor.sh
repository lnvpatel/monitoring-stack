#!/bin/bash

# ==========================================
# CPU Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Displays CPU model, core count, current
#   usage percentage, load averages with
#   classification (LOW/MODERATE/HIGH/CRITICAL),
#   and top CPU-consuming processes.
#
# Usage:
#   ./cpu-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"
CPU_THRESHOLD=80

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   CPU Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── CPU Hardware Info ─────────────────────────────────────────────────────────
echo -e "${BOLD}── CPU Hardware ────────────────────────────${RESET}"
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
CPU_CORES=$(nproc --all)
CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo)
CPU_SOCKETS=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
CPU_ARCH=$(uname -m)
CPU_MHZ=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{printf "%.0f", $4}')

echo -e "  Model   : ${BOLD}${CPU_MODEL}${RESET}"
echo -e "  Cores   : ${BOLD}${CPU_CORES}${RESET}  |  Threads : ${BOLD}${CPU_THREADS}${RESET}  |  Sockets : ${BOLD}${CPU_SOCKETS}${RESET}"
echo -e "  Arch    : ${BOLD}${CPU_ARCH}${RESET}  |  Speed   : ${BOLD}${CPU_MHZ} MHz${RESET}"

# CPU cache
L2_CACHE=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "N/A")
echo -e "  L2 Cache: ${BOLD}${L2_CACHE}${RESET}"

# ── CPU Usage ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── CPU Usage ───────────────────────────────${RESET}"
# Get idle % from top, convert to usage
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1 2>/dev/null)
# Fallback: try different top output formats
if [[ -z "$CPU_IDLE" ]]; then
    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed 's/.*,\s*\([0-9.]*\)\s*id.*/\1/' | cut -d. -f1)
fi
CPU_USAGE=$(( 100 - ${CPU_IDLE:-0} ))

# Get individual CPU stats from /proc/stat (more reliable)
read -ra cpu_stats1 < <(grep "^cpu " /proc/stat)
sleep 0.5
read -ra cpu_stats2 < <(grep "^cpu " /proc/stat)

IDLE1=${cpu_stats1[4]}; TOTAL1=0
for v in "${cpu_stats1[@]:1}"; do TOTAL1=$((TOTAL1 + v)); done

IDLE2=${cpu_stats2[4]}; TOTAL2=0
for v in "${cpu_stats2[@]:1}"; do TOTAL2=$((TOTAL2 + v)); done

D_IDLE=$((IDLE2 - IDLE1))
D_TOTAL=$((TOTAL2 - TOTAL1))
if [ "$D_TOTAL" -gt 0 ]; then
    CPU_USAGE=$(awk "BEGIN {printf \"%.1f\", (1 - $D_IDLE/$D_TOTAL) * 100}")
fi
CPU_USAGE_INT=$(echo "$CPU_USAGE" | cut -d. -f1)

echo -e "  Current Usage : ${BOLD}${CPU_USAGE}%${RESET}  (threshold: ${CPU_THRESHOLD}%)"
echo ""

if   [ "$CPU_USAGE_INT" -ge "$CPU_THRESHOLD" ]; then
    echo -e "  ${RED}[CRITICAL]${RESET} CPU is OVERLOADED: ${CPU_USAGE}%"
elif [ "$CPU_USAGE_INT" -ge $((CPU_THRESHOLD - 20)) ]; then
    echo -e "  ${YELLOW}[WARNING]${RESET}  CPU usage is HIGH: ${CPU_USAGE}%"
elif [ "$CPU_USAGE_INT" -ge 40 ]; then
    echo -e "  ${YELLOW}[MODERATE]${RESET} CPU usage is moderate: ${CPU_USAGE}%"
else
    echo -e "  ${GREEN}[  LOW  ]${RESET}  CPU usage is low: ${CPU_USAGE}%"
fi

# ── Load Averages ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Load Averages ───────────────────────────${RESET}"
LOAD_1=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
LOAD_15=$(awk '{print $3}' /proc/loadavg)
echo -e "  1 min  : ${BOLD}${LOAD_1}${RESET}"
echo -e "  5 min  : ${BOLD}${LOAD_5}${RESET}"
echo -e "  15 min : ${BOLD}${LOAD_15}${RESET}"
echo -e "  Cores  : ${BOLD}${CPU_CORES}${RESET}"
echo ""

# Classify load relative to core count
LOAD_1_X10=$(echo "$LOAD_1" | awk '{printf "%d", $1 * 10}')
CORES_X10=$((CPU_CORES * 10))

if   [ "$LOAD_1_X10" -gt $((CORES_X10 * 2)) ]; then
    echo -e "  ${RED}[CRITICAL]${RESET} Load is VERY HIGH (${LOAD_1} > ${CPU_CORES} cores × 2)"
elif [ "$LOAD_1_X10" -gt "$CORES_X10" ]; then
    echo -e "  ${YELLOW}[WARNING]${RESET}  Load exceeds available cores (${LOAD_1} > ${CPU_CORES})"
elif [ "$LOAD_1_X10" -gt $((CORES_X10 * 7 / 10)) ]; then
    echo -e "  ${YELLOW}[MODERATE]${RESET} Load is moderate (${LOAD_1} / ${CPU_CORES} cores)"
else
    echo -e "  ${GREEN}[  OK  ]${RESET}  Load is normal (${LOAD_1} / ${CPU_CORES} cores)"
fi

# ── Per-Core Stats (via mpstat if available) ──────────────────────────────────
echo ""
echo -e "${BOLD}── Per-Core Usage ──────────────────────────${RESET}"
if command -v mpstat &>/dev/null; then
    mpstat -P ALL 1 1 2>/dev/null | grep -E "^(Average|[0-9])" | grep -v "^Average.*all" | \
        awk 'NR>1 {printf "  Core %-4s  usr: %5s%%   sys: %5s%%   idle: %5s%%\n", $3, $4, $6, $NF}'
else
    echo -e "  ${YELLOW}[INFO]${RESET} Install 'sysstat' for per-core stats: sudo apt install sysstat"
    # Fallback: parse /proc/stat for each CPU
    grep "^cpu[0-9]" /proc/stat | head -8 | while read -r cpu_line; do
        read -ra vals <<< "$cpu_line"
        CORE=${vals[0]}
        TOTAL=0; for v in "${vals[@]:1}"; do TOTAL=$((TOTAL + v)); done
        IDLE=${vals[4]}
        if [ "$TOTAL" -gt 0 ]; then
            USAGE=$(awk "BEGIN {printf \"%.1f\", (1 - $IDLE/$TOTAL) * 100}")
            echo -e "  ${CORE}    usage ≈ ${USAGE}%  (snapshot – run mpstat for accuracy)"
        fi
    done
fi

# ── Top 10 CPU-Consuming Processes ────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Top 10 CPU-Consuming Processes ──────────${RESET}"
printf "  %-8s %-6s %-6s %-s\n" "PID" "%CPU" "%MEM" "COMMAND"
echo "  ----------------------------------------"
ps -eo pid,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -11 | tail -10 | \
    while read -r pid cpu mem comm; do
        printf "  %-8s %-6s %-6s %-s\n" "$pid" "$cpu" "$mem" "$comm"
    done

# ── CPU Context Switches & Interrupts ─────────────────────────────────────────
echo ""
echo -e "${BOLD}── Kernel CPU Stats (from /proc/stat) ──────${RESET}"
CTXT=$(grep "^ctxt" /proc/stat | awk '{print $2}')
INTR=$(grep "^intr" /proc/stat | awk '{print $2}')
PROCS=$(grep "^processes" /proc/stat | awk '{print $2}')
echo -e "  Context Switches (total) : ${BOLD}${CTXT}${RESET}"
echo -e "  Interrupts (total)       : ${BOLD}${INTR}${RESET}"
echo -e "  Processes created (boot) : ${BOLD}${PROCS}${RESET}"

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  CPU monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
