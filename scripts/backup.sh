#!/bin/bash

# ==========================================
# Backup Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Creates a compressed tar.gz backup of
#   a target directory with timestamp.
#   Automatically rotates old backups,
#   keeping only the most recent N copies.
#
# Usage:
#   ./backup.sh                          (uses defaults below)
#   ./backup.sh /path/to/source          (custom source)
#   ./backup.sh /path/to/source /backups (custom source + destination)
#
# Cron Example (daily at 2am):
#   0 2 * * * /path/to/backup.sh /etc /var/backups/etc-backups >> /var/log/backup.log 2>&1
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

# ── Configuration ──────────────────────────────────────────────────────────────
# Default source directory to back up (override via argument or edit here)
SOURCE_DIR="${1:-$HOME}"

# Default backup destination
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DEST="${2:-$SCRIPT_DIR/../backups}"

# How many backup copies to keep (older ones will be deleted)
MAX_BACKUPS=5

# Backup filename prefix
PREFIX="backup"

# ── Timestamp & Filename ───────────────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
HOSTNAME_SHORT=$(hostname -s)
SOURCE_BASENAME=$(basename "$SOURCE_DIR")
BACKUP_FILENAME="${PREFIX}_${HOSTNAME_SHORT}_${SOURCE_BASENAME}_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_DEST}/${BACKUP_FILENAME}"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Backup Script${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname    : $(hostname)"
echo -e "  Date        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo -e "  Source      : ${BOLD}${SOURCE_DIR}${RESET}"
echo -e "  Destination : ${BOLD}${BACKUP_DEST}${RESET}"
echo -e "  Filename    : ${BOLD}${BACKUP_FILENAME}${RESET}"
echo -e "  Keep last   : ${BOLD}${MAX_BACKUPS} backups${RESET}"
echo ""

# ── Validate Source ────────────────────────────────────────────────────────────
if [ ! -e "$SOURCE_DIR" ]; then
    echo -e "  ${RED}[ERROR]${RESET} Source path does not exist: ${SOURCE_DIR}"
    exit 1
fi

if [ ! -r "$SOURCE_DIR" ]; then
    echo -e "  ${RED}[ERROR]${RESET} Cannot read source: ${SOURCE_DIR}"
    echo -e "  ${YELLOW}[TIP]${RESET}  Run with sudo for system directories"
    exit 1
fi

# ── Create Destination Directory ──────────────────────────────────────────────
mkdir -p "$BACKUP_DEST" || {
    echo -e "  ${RED}[ERROR]${RESET} Cannot create backup directory: ${BACKUP_DEST}"
    exit 1
}

# ── Calculate Source Size ──────────────────────────────────────────────────────
SOURCE_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')
echo -e "  Source size : ${BOLD}${SOURCE_SIZE}${RESET}"
echo ""
echo -e "  ${CYAN}[INFO]${RESET} Starting backup..."

# ── Run Backup ────────────────────────────────────────────────────────────────
START_TIME=$(date +%s)

tar -czf "$BACKUP_PATH" \
    --exclude="$BACKUP_DEST" \
    --exclude="*.sock" \
    --exclude="*.pid" \
    --warning=no-file-changed \
    "$SOURCE_DIR" 2>/dev/null

TAR_EXIT=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# ── Check Result ───────────────────────────────────────────────────────────────
if [ "$TAR_EXIT" -eq 0 ] || [ "$TAR_EXIT" -eq 1 ]; then
    # Exit code 1 from tar = some files changed during backup (normal for live systems)
    BACKUP_SIZE=$(du -sh "$BACKUP_PATH" 2>/dev/null | awk '{print $1}')
    echo -e "  ${GREEN}[ SUCCESS ]${RESET} Backup created successfully!"
    echo ""
    echo -e "  File     : ${BOLD}${BACKUP_PATH}${RESET}"
    echo -e "  Size     : ${BOLD}${BACKUP_SIZE}${RESET}"
    echo -e "  Duration : ${BOLD}${DURATION} second(s)${RESET}"
else
    echo -e "  ${RED}[  ERROR ]${RESET} Backup failed with exit code: ${TAR_EXIT}"
    rm -f "$BACKUP_PATH"
    exit 1
fi

# ── Verify Integrity ──────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}[INFO]${RESET} Verifying backup integrity..."
if tar -tzf "$BACKUP_PATH" &>/dev/null; then
    FILE_COUNT=$(tar -tzf "$BACKUP_PATH" 2>/dev/null | wc -l)
    echo -e "  ${GREEN}[ VERIFY ]${RESET} Archive is valid. Contains ${BOLD}${FILE_COUNT}${RESET} entries."
else
    echo -e "  ${RED}[ CORRUPT]${RESET} Archive verification FAILED! Backup may be corrupt."
    exit 1
fi

# ── Backup Rotation ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Backup Rotation ─────────────────────────${RESET}"
echo -e "  Keeping last ${BOLD}${MAX_BACKUPS}${RESET} backups. Removing older ones..."

BACKUP_COUNT=$(ls -1 "${BACKUP_DEST}/${PREFIX}_${HOSTNAME_SHORT}_${SOURCE_BASENAME}_"*.tar.gz 2>/dev/null | wc -l)
echo -e "  Total backups found : ${BOLD}${BACKUP_COUNT}${RESET}"

if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    DELETE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
    echo -e "  Removing ${BOLD}${DELETE_COUNT}${RESET} old backup(s)..."

    ls -1t "${BACKUP_DEST}/${PREFIX}_${HOSTNAME_SHORT}_${SOURCE_BASENAME}_"*.tar.gz 2>/dev/null | \
        tail -n "$DELETE_COUNT" | while read -r old_backup; do
            rm -f "$old_backup"
            echo -e "  ${YELLOW}[DELETED]${RESET} $(basename "$old_backup")"
        done
else
    echo -e "  ${GREEN}[  OK   ]${RESET} No rotation needed (${BACKUP_COUNT}/${MAX_BACKUPS} slots used)"
fi

# ── List Current Backups ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Current Backups ─────────────────────────${RESET}"
ls -lh "${BACKUP_DEST}/${PREFIX}_${HOSTNAME_SHORT}_${SOURCE_BASENAME}_"*.tar.gz 2>/dev/null | \
    while IFS= read -r line; do
        echo "  $line"
    done

# ── Disk Space Check ───────────────────────────────────────────────────────────
DEST_USAGE=$(df -h "$BACKUP_DEST" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
echo ""
if [ "$DEST_USAGE" -ge 80 ]; then
    echo -e "  ${YELLOW}[WARN]${RESET}  Backup disk is ${DEST_USAGE}% full. Consider moving backups off-site."
else
    echo -e "  ${GREEN}[ OK  ]${RESET}  Backup disk usage: ${DEST_USAGE}%"
fi

# ── Restore Instructions ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── How to Restore ──────────────────────────${RESET}"
echo -e "  To restore this backup, run:"
echo -e "  ${CYAN}tar -xzf ${BACKUP_PATH} -C /restore/location/${RESET}"
echo -e ""
echo -e "  To list backup contents:"
echo -e "  ${CYAN}tar -tzf ${BACKUP_PATH} | head -50${RESET}"

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Backup completed successfully."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
