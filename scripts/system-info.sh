#!/bin/bash

# ==========================================
# System Information Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Displays a comprehensive system summary
#   including OS, kernel, hardware, network,
#   and environment info. Professional
#   alternative to neofetch for sysadmins.
#
# Usage:
#   ./system-info.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BLUE="\e[0;34m" MAGENTA="\e[0;35m"
BOLD="\e[1m" RESET="\e[0m"

# ── Collect data ──────────────────────────────────────────────────────────────

# OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-Unknown}"
    OS_ID="${ID:-unknown}"
else
    OS_NAME=$(uname -o)
fi

KERNEL=$(uname -r)
ARCH=$(uname -m)
HOSTNAME_FULL=$(hostname -f 2>/dev/null || hostname)
HOSTNAME_SHORT=$(hostname -s)

# CPU
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
CPU_CORES=$(nproc --all)
CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo)
CPU_MHZ=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{printf "%.0f", $4}')
LOAD_1=$(awk '{print $1}' /proc/loadavg)

# Memory
MEM_TOTAL_H=$(free -h | awk '/Mem:/ {print $2}')
MEM_USED_H=$(free -h  | awk '/Mem:/ {print $3}')
MEM_AVAIL_H=$(free -h | awk '/Mem:/ {print $7}')
MEM_PCT=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
SWAP_TOTAL_H=$(free -h | awk '/Swap:/ {print $2}')
SWAP_USED_H=$(free -h  | awk '/Swap:/ {print $3}')

# Disk
DISK_ROOT_USED=$(df -h / | awk 'NR==2{print $3}')
DISK_ROOT_TOTAL=$(df -h / | awk 'NR==2{print $2}')
DISK_ROOT_PCT=$(df / | awk 'NR==2{print $5}')

# Network
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
PRIMARY_IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
DEFAULT_GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
MAC_ADDR=$(cat "/sys/class/net/${PRIMARY_IF}/address" 2>/dev/null || echo "N/A")
DNS_SERVER=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')

# Uptime
UPTIME_SECS=$(awk '{printf "%d", $1}' /proc/uptime)
UP_DAYS=$((UPTIME_SECS / 86400))
UP_HOURS=$(( (UPTIME_SECS % 86400) / 3600 ))
UP_MINS=$(( (UPTIME_SECS % 3600) / 60 ))

# Processes
PROC_COUNT=$(ps aux --no-headers 2>/dev/null | wc -l)
RUNNING_SERVICES=$(systemctl list-units --type=service --state=running \
    --no-legend 2>/dev/null | wc -l)
FAILED_SERVICES=$(systemctl list-units --type=service --state=failed \
    --no-legend 2>/dev/null | wc -l)

# Users
LOGGED_USERS=$(who | wc -l)
TOTAL_USERS=$(grep -c "^[^#]" /etc/passwd 2>/dev/null || echo "N/A")

# Timezone
TZ_INFO=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || date +%Z)

# Last boot
BOOT_TIME=$(uptime -s 2>/dev/null || who -b | awk '{print $3, $4}')

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "   ███████╗██╗   ██╗███████╗    ██╗███╗   ██╗███████╗ ██████╗"
echo "   ██╔════╝╚██╗ ██╔╝██╔════╝    ██║████╗  ██║██╔════╝██╔═══██╗"
echo "   ███████╗ ╚████╔╝ ███████╗    ██║██╔██╗ ██║█████╗  ██║   ██║"
echo "   ╚════██║  ╚██╔╝  ╚════██║    ██║██║╚██╗██║██╔══╝  ██║   ██║"
echo "   ███████║   ██║   ███████║    ██║██║ ╚████║██║     ╚██████╔╝"
echo "   ╚══════╝   ╚═╝   ╚══════╝    ╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝"
echo -e "${RESET}"

echo -e "${BOLD}${CYAN}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}  ║              System Information Report                    ║${RESET}"
echo -e "${BOLD}${CYAN}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── OS & Identity ─────────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ 🖥️  Identity & OS ──────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}Hostname   ${RESET}: ${BOLD}${HOSTNAME_FULL}${RESET}"
echo -e "  │  ${CYAN}OS         ${RESET}: ${BOLD}${OS_NAME}${RESET}"
echo -e "  │  ${CYAN}Kernel     ${RESET}: ${BOLD}${KERNEL}${RESET}"
echo -e "  │  ${CYAN}Arch       ${RESET}: ${BOLD}${ARCH}${RESET}"
echo -e "  │  ${CYAN}Timezone   ${RESET}: ${BOLD}${TZ_INFO}${RESET}"
echo -e "  │  ${CYAN}Date/Time  ${RESET}: ${BOLD}$(date '+%A, %d %B %Y  %H:%M:%S')${RESET}"
echo -e "  └──────────────────────────────────────────────────────────"
echo ""

# ── Hardware ──────────────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ ⚙️  Hardware ─────────────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}CPU Model  ${RESET}: ${BOLD}${CPU_MODEL}${RESET}"
echo -e "  │  ${CYAN}Cores      ${RESET}: ${BOLD}${CPU_CORES} physical / ${CPU_THREADS} logical${RESET}"
echo -e "  │  ${CYAN}CPU Speed  ${RESET}: ${BOLD}${CPU_MHZ} MHz${RESET}"
echo -e "  │  ${CYAN}Load (1m)  ${RESET}: ${BOLD}${LOAD_1}${RESET}"
echo -e "  └──────────────────────────────────────────────────────────"
echo ""

# ── Memory ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ 🧠 Memory ─────────────────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}RAM Total  ${RESET}: ${BOLD}${MEM_TOTAL_H}${RESET}"
echo -e "  │  ${CYAN}RAM Used   ${RESET}: ${BOLD}${MEM_USED_H}${RESET}  (${MEM_PCT}%)"
echo -e "  │  ${CYAN}Available  ${RESET}: ${BOLD}${MEM_AVAIL_H}${RESET}"
echo -e "  │  ${CYAN}Swap Total ${RESET}: ${BOLD}${SWAP_TOTAL_H}${RESET}  |  Used: ${BOLD}${SWAP_USED_H}${RESET}"
echo -e "  └──────────────────────────────────────────────────────────"
echo ""

# ── Disk ──────────────────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ 💾 Disk ───────────────────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}Root (/)   ${RESET}: ${BOLD}${DISK_ROOT_USED} / ${DISK_ROOT_TOTAL}${RESET}  (${DISK_ROOT_PCT})"
echo ""
# All filesystems
df -hx tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2 | \
    while IFS= read -r line; do
        FS=$(echo "$line" | awk '{print $1}')
        USED=$(echo "$line" | awk '{print $3}')
        SIZE=$(echo "$line" | awk '{print $2}')
        PCT=$(echo "$line" | awk '{print $5}')
        MNT=$(echo "$line" | awk '{print $6}')
        echo -e "  │  ${CYAN}${MNT}        ${RESET}: ${BOLD}${USED} / ${SIZE}${RESET}  ${PCT}"
    done
echo -e "  └──────────────────────────────────────────────────────────"
echo ""

# ── Network ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ 🌐 Network ────────────────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}Primary IP ${RESET}: ${BOLD}${PRIMARY_IP}${RESET}  (${PRIMARY_IF})"
echo -e "  │  ${CYAN}Gateway    ${RESET}: ${BOLD}${DEFAULT_GW:-N/A}${RESET}"
echo -e "  │  ${CYAN}MAC Addr   ${RESET}: ${BOLD}${MAC_ADDR}${RESET}"
echo -e "  │  ${CYAN}DNS Server ${RESET}: ${BOLD}${DNS_SERVER:-N/A}${RESET}"
echo ""
# All interfaces
ip -brief address 2>/dev/null | while read -r iface state addr; do
    echo -e "  │  ${CYAN}${iface}       ${RESET}: ${BOLD}${state}${RESET}  ${addr}"
done
echo -e "  └──────────────────────────────────────────────────────────"
echo ""

# ── Uptime & Services ─────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ 🕐 Uptime & Services ──────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}Uptime     ${RESET}: ${BOLD}${UP_DAYS}d ${UP_HOURS}h ${UP_MINS}m${RESET}"
echo -e "  │  ${CYAN}Boot Time  ${RESET}: ${BOLD}${BOOT_TIME}${RESET}"
echo -e "  │  ${CYAN}Processes  ${RESET}: ${BOLD}${PROC_COUNT}${RESET}"
echo -e "  │  ${CYAN}Services   ${RESET}: ${GREEN}${BOLD}${RUNNING_SERVICES} running${RESET}  /  ${RED}${BOLD}${FAILED_SERVICES} failed${RESET}"
echo -e "  │  ${CYAN}Users      ${RESET}: ${BOLD}${LOGGED_USERS} logged in${RESET}  /  ${TOTAL_USERS} total accounts"
echo -e "  └──────────────────────────────────────────────────────────"
echo ""

# ── Docker (if installed) ─────────────────────────────────────────────────────
if command -v docker &>/dev/null && docker info &>/dev/null; then
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
    IMAGES=$(docker images -q 2>/dev/null | wc -l)
    echo -e "${BOLD}  ┌─ 🐳 Docker ─────────────────────────────────────────────────────${RESET}"
    echo -e "  │  ${CYAN}Version    ${RESET}: ${BOLD}${DOCKER_VER}${RESET}"
    echo -e "  │  ${CYAN}Running    ${RESET}: ${BOLD}${CONTAINERS} container(s)${RESET}"
    echo -e "  │  ${CYAN}Images     ${RESET}: ${BOLD}${IMAGES} image(s)${RESET}"
    echo -e "  └──────────────────────────────────────────────────────────"
    echo ""
fi

# ── Environment ───────────────────────────────────────────────────────────────
echo -e "${BOLD}  ┌─ 🔧 Environment ────────────────────────────────────────────────${RESET}"
echo -e "  │  ${CYAN}Shell      ${RESET}: ${BOLD}${SHELL}${RESET}"
echo -e "  │  ${CYAN}User       ${RESET}: ${BOLD}$(whoami)${RESET}"
echo -e "  │  ${CYAN}Bash Ver.  ${RESET}: ${BOLD}${BASH_VERSION}${RESET}"

# Cloud environment detection
if curl -fs --max-time 1 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
    INSTANCE_ID=$(curl -fs --max-time 1 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
    REGION=$(curl -fs --max-time 1 http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "N/A")
    echo -e "  │  ${CYAN}Cloud      ${RESET}: ${BOLD}${GREEN}AWS EC2${RESET} – Instance: ${INSTANCE_ID}  Region: ${REGION}"
elif curl -fs --max-time 1 -H "Metadata-Flavor: Google" http://metadata.google.internal/ &>/dev/null; then
    echo -e "  │  ${CYAN}Cloud      ${RESET}: ${BOLD}${GREEN}Google Cloud Platform (GCP)${RESET}"
elif curl -fs --max-time 1 -H "Metadata: true" "http://169.254.169.254/metadata/instance" &>/dev/null; then
    echo -e "  │  ${CYAN}Cloud      ${RESET}: ${BOLD}${GREEN}Microsoft Azure${RESET}"
else
    echo -e "  │  ${CYAN}Cloud      ${RESET}: ${BOLD}Bare metal / local VM / not detected${RESET}"
fi

echo -e "  └──────────────────────────────────────────────────────────"
echo ""
echo -e "${BOLD}${CYAN}  ═══════════════════════════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}${GREEN}System information report completed.${RESET}"
echo -e "${BOLD}${CYAN}  ═══════════════════════════════════════════════════════════════${RESET}"
echo ""
