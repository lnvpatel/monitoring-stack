#!/bin/bash

# ==========================================
# Disk Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Reports disk usage across all mounted
#   filesystems, inode usage, and identifies
#   the largest directories consuming space.
#
# Usage:
#   ./disk-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"
DISK_THRESHOLD=80
INODE_THRESHOLD=80

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Disk Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Filesystem Usage ──────────────────────────────────────────────────────────
echo -e "${BOLD}── Filesystem Usage (threshold: ${DISK_THRESHOLD}%) ───${RESET}"
printf "  %-25s %-8s %-8s %-8s %-6s %-s\n" "FILESYSTEM" "SIZE" "USED" "AVAIL" "USE%" "MOUNT"
echo "  -----------------------------------------------------------------------"

ALERT_FOUND=0
while IFS= read -r line; do
    FS=$(echo "$line"    | awk '{print $1}')
    SIZE=$(echo "$line"  | awk '{print $2}')
    USED=$(echo "$line"  | awk '{print $3}')
    AVAIL=$(echo "$line" | awk '{print $4}')
    PCT=$(echo "$line"   | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo "$line" | awk '{print $6}')

    if   [ "$PCT" -ge "$DISK_THRESHOLD" ]; then
        printf "  ${RED}%-25s %-8s %-8s %-8s %-6s %-s${RESET}\n" "$FS" "$SIZE" "$USED" "$AVAIL" "${PCT}%" "$MOUNT"
        ALERT_FOUND=1
    elif [ "$PCT" -ge $((DISK_THRESHOLD - 15)) ]; then
        printf "  ${YELLOW}%-25s %-8s %-8s %-8s %-6s %-s${RESET}\n" "$FS" "$SIZE" "$USED" "$AVAIL" "${PCT}%" "$MOUNT"
        ALERT_FOUND=1
    else
        printf "  ${GREEN}%-25s %-8s %-8s %-8s %-6s %-s${RESET}\n" "$FS" "$SIZE" "$USED" "$AVAIL" "${PCT}%" "$MOUNT"
    fi
done < <(df -hx tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2)

echo ""
if [ "$ALERT_FOUND" -eq 1 ]; then
    echo -e "  ${YELLOW}[INFO]${RESET} Some filesystems are approaching or exceeding threshold (${DISK_THRESHOLD}%)"
else
    echo -e "  ${GREEN}[  OK ]${RESET} All filesystems within normal limits"
fi

# ── Inode Usage ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Inode Usage (threshold: ${INODE_THRESHOLD}%) ─────────${RESET}"
echo -e "  ${CYAN}Note: Running out of inodes = cannot create files, even with free space${RESET}"
printf "  %-25s %-10s %-10s %-10s %-s\n" "FILESYSTEM" "INODES" "IUSED" "IFREE" "IUSE%"
echo "  -----------------------------------------------------------------------"

df -ix tmpfs -x devtmpfs -x squashfs --output=source,itotal,iused,iavail,ipcent 2>/dev/null | \
    tail -n +2 | while IFS= read -r line; do
    FS=$(echo "$line"    | awk '{print $1}')
    ITOTAL=$(echo "$line" | awk '{print $2}')
    IUSED=$(echo "$line"  | awk '{print $3}')
    IFREE=$(echo "$line"  | awk '{print $4}')
    IPCT=$(echo "$line"   | awk '{print $5}' | sed 's/%//' | tr -d '-')

    if [[ "$IPCT" =~ ^[0-9]+$ ]]; then
        if [ "$IPCT" -ge "$INODE_THRESHOLD" ]; then
            printf "  ${RED}%-25s %-10s %-10s %-10s %s%%${RESET}\n" "$FS" "$ITOTAL" "$IUSED" "$IFREE" "$IPCT"
        else
            printf "  ${GREEN}%-25s %-10s %-10s %-10s %s%%${RESET}\n" "$FS" "$ITOTAL" "$IUSED" "$IFREE" "$IPCT"
        fi
    else
        printf "  %-25s %-10s %-10s %-10s %s\n" "$FS" "$ITOTAL" "$IUSED" "$IFREE" "${IPCT}%"
    fi
done

# ── Disk I/O Stats ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Disk I/O Activity ───────────────────────${RESET}"
if command -v iostat &>/dev/null; then
    iostat -d 1 1 2>/dev/null | grep -v "^$" | tail -n +3
else
    echo -e "  ${YELLOW}[INFO]${RESET} Install 'sysstat' for I/O stats: sudo apt install sysstat"
    # Fallback from /proc/diskstats
    echo ""
    echo -e "  Block Device Stats (/proc/diskstats):"
    printf "  %-12s %-12s %-12s\n" "DEVICE" "READS" "WRITES"
    echo "  ----------------------------------------"
    awk '$3 ~ /^(sd|nvme|vd|hd)/ && $3 !~ /[0-9]$/ {
        printf "  %-12s %-12s %-12s\n", $3, $4, $8
    }' /proc/diskstats | head -10
fi

# ── Largest Directories ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Top 10 Largest Directories ──────────────${RESET}"
echo -e "  ${CYAN}(scanning /var, /tmp, /home, /opt — this may take a moment)${RESET}"
echo ""
for DIR in /var /tmp /home /opt; do
    if [ -d "$DIR" ]; then
        echo -e "  ${BOLD}${DIR}${RESET}"
        du -sh "$DIR"/*/  2>/dev/null | sort -rh | head -5 | \
            while read -r size path; do
                printf "    %-10s %s\n" "$size" "$path"
            done
        echo ""
    fi
done

# ── Large Files Alert ──────────────────────────────────────────────────────────
echo -e "${BOLD}── Files Larger Than 100MB ─────────────────${RESET}"
echo -e "  ${CYAN}(scanning /home and /var — excludes /proc and /sys)${RESET}"
echo ""
find /home /var -maxdepth 5 -type f -size +100M 2>/dev/null | while read -r f; do
    SIZE=$(du -sh "$f" 2>/dev/null | awk '{print $1}')
    printf "  %-10s %s\n" "$SIZE" "$f"
done | head -20

if [ $? -ne 0 ] || ! find /home /var -maxdepth 5 -type f -size +100M 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}[  OK ]${RESET} No files larger than 100MB found in /home and /var"
fi

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Disk monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
