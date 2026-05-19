#!/bin/bash

# ==========================================
# Network Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Reports network interface status, IP
#   addressing, gateway, DNS, connectivity
#   tests, listening ports, and active
#   connection counts.
#
# Usage:
#   ./network-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Network Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Network Interfaces ────────────────────────────────────────────────────────
echo -e "${BOLD}── Network Interfaces ──────────────────────${RESET}"
ip -brief address 2>/dev/null | while read -r iface state rest; do
    if [[ "$state" == "UP" ]]; then
        echo -e "  ${GREEN}[ UP   ]${RESET}  ${BOLD}${iface}${RESET}   ${rest}"
    elif [[ "$state" == "DOWN" ]]; then
        echo -e "  ${RED}[ DOWN ]${RESET}  ${BOLD}${iface}${RESET}"
    else
        echo -e "  ${YELLOW}[ ${state} ]${RESET}  ${BOLD}${iface}${RESET}   ${rest}"
    fi
done

# ── Routing & Gateway ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Routing Table (default routes) ──────────${RESET}"
ip route show 2>/dev/null | while IFS= read -r line; do
    echo "  $line"
done

DEFAULT_GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
DEFAULT_IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
echo ""
echo -e "  Default Gateway : ${BOLD}${DEFAULT_GW:-Not configured}${RESET}"
echo -e "  Via Interface   : ${BOLD}${DEFAULT_IF:-N/A}${RESET}"

# ── DNS Configuration ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── DNS Servers ─────────────────────────────${RESET}"
if [ -f /etc/resolv.conf ]; then
    grep "^nameserver" /etc/resolv.conf | while read -r _ ns; do
        echo -e "  Nameserver : ${BOLD}${ns}${RESET}"
    done
fi

# systemd-resolved
if command -v resolvectl &>/dev/null; then
    echo ""
    resolvectl status 2>/dev/null | grep -E "(DNS Servers|Current DNS|DNS Domain)" | \
        while IFS= read -r line; do echo "  $line"; done
fi

# ── Connectivity Tests ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Connectivity Tests ──────────────────────${RESET}"
declare -A TARGETS=(
    ["Google DNS (8.8.8.8)"]="8.8.8.8"
    ["Cloudflare DNS (1.1.1.1)"]="1.1.1.1"
    ["Google (google.com)"]="google.com"
)

for label in "${!TARGETS[@]}"; do
    host="${TARGETS[$label]}"
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        RTT=$(ping -c 1 -W 2 "$host" 2>/dev/null | grep "time=" | awk -F"time=" '{print $2}' | cut -d" " -f1)
        echo -e "  ${GREEN}[ REACHABLE ]${RESET}  ${label}   ${CYAN}(${RTT} ms)${RESET}"
    else
        echo -e "  ${RED}[UNREACHABLE]${RESET}  ${label}"
    fi
done

# HTTPS check
if curl -fs --max-time 5 https://google.com -o /dev/null 2>/dev/null; then
    echo -e "  ${GREEN}[ HTTPS OK  ]${RESET}  Internet HTTPS access confirmed"
else
    echo -e "  ${RED}[ HTTPS ERR ]${RESET}  Cannot reach internet via HTTPS"
fi

# ── Active Connections ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Active Connections Summary ───────────────${RESET}"
TOTAL_CONN=$(ss -s 2>/dev/null | grep "^Total:" | awk '{print $2}')
TCP_ESTAB=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
TCP_LISTEN=$(ss -tn state listen 2>/dev/null | tail -n +2 | wc -l)
UDP_CONN=$(ss -un 2>/dev/null | tail -n +2 | wc -l)

echo -e "  Total sockets     : ${BOLD}${TOTAL_CONN}${RESET}"
echo -e "  TCP Established   : ${BOLD}${TCP_ESTAB}${RESET}"
echo -e "  TCP Listening     : ${BOLD}${TCP_LISTEN}${RESET}"
echo -e "  UDP               : ${BOLD}${UDP_CONN}${RESET}"

# ── Listening Ports ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Listening Ports (with processes) ────────${RESET}"
echo -e "  ${CYAN}Run with sudo for full process names${RESET}"
echo ""
printf "  %-8s %-25s %-10s %-s\n" "PROTO" "LOCAL ADDRESS" "STATE" "PROCESS"
echo "  ---------------------------------------------------------------"
ss -tulnp 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    PROTO=$(echo "$line" | awk '{print $1}')
    STATE=$(echo "$line" | awk '{print $2}')
    LADDR=$(echo "$line" | awk '{print $5}')
    PROC=$(echo "$line"  | awk '{print $NF}' | grep -oP '(?<=name=)[^,)]+' || echo "-")
    printf "  %-8s %-25s %-10s %-s\n" "$PROTO" "$LADDR" "$STATE" "$PROC"
done | head -30

# ── Network Interface Statistics ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Interface Traffic Statistics ─────────────${RESET}"
printf "  %-12s %-15s %-15s %-10s %-10s\n" "INTERFACE" "RX BYTES" "TX BYTES" "RX PKTS" "TX PKTS"
echo "  ---------------------------------------------------------------"
for iface_dir in /sys/class/net/*/; do
    iface=$(basename "$iface_dir")
    [[ "$iface" == "lo" ]] && continue
    RX_BYTES=$(cat "$iface_dir/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX_BYTES=$(cat "$iface_dir/statistics/tx_bytes" 2>/dev/null || echo 0)
    RX_PKTS=$(cat  "$iface_dir/statistics/rx_packets" 2>/dev/null || echo 0)
    TX_PKTS=$(cat  "$iface_dir/statistics/tx_packets" 2>/dev/null || echo 0)
    # Convert bytes to MB
    RX_MB=$(awk "BEGIN {printf \"%.1f MB\", $RX_BYTES/1048576}")
    TX_MB=$(awk "BEGIN {printf \"%.1f MB\", $TX_BYTES/1048576}")
    printf "  %-12s %-15s %-15s %-10s %-10s\n" "$iface" "$RX_MB" "$TX_MB" "$RX_PKTS" "$TX_PKTS"
done

# ── /etc/hosts ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── /etc/hosts Entries ──────────────────────${RESET}"
grep -v "^#\|^$" /etc/hosts 2>/dev/null | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Network monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
