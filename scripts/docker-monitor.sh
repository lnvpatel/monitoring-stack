#!/bin/bash

# ==========================================
# Docker Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Reports Docker daemon status, running
#   and stopped containers with resource
#   usage, image inventory, volumes, and
#   networks.
#
# Usage:
#   ./docker-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Docker Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Docker Installation Check ─────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo -e "  ${YELLOW}[INFO]${RESET} Docker is not installed on this system."
    echo -e "         To install: sudo apt install docker.io   (Debian/Ubuntu)"
    echo -e "                  or follow: https://docs.docker.com/engine/install/"
    exit 0
fi

# ── Docker Daemon Status ──────────────────────────────────────────────────────
echo -e "${BOLD}── Docker Daemon ───────────────────────────${RESET}"
DOCKER_VERSION=$(docker --version 2>/dev/null)
echo -e "  Version : ${BOLD}${DOCKER_VERSION}${RESET}"

if systemctl is-active --quiet docker 2>/dev/null; then
    echo -e "  Daemon  : ${GREEN}RUNNING${RESET}"
elif docker info &>/dev/null; then
    echo -e "  Daemon  : ${GREEN}RUNNING${RESET} (rootless mode)"
else
    echo -e "  Daemon  : ${RED}NOT RUNNING${RESET}"
    echo -e "  ${YELLOW}[FIX]${RESET} Start with: sudo systemctl start docker"
    exit 1
fi

# Docker server info summary
DOCKER_INFO=$(docker info 2>/dev/null)
CONTAINERS_TOTAL=$(echo "$DOCKER_INFO" | awk '/^Containers:/ {print $2}')
CONTAINERS_RUN=$(echo "$DOCKER_INFO"   | awk '/Running:/ {print $2}')
CONTAINERS_STOP=$(echo "$DOCKER_INFO"  | awk '/Stopped:/ {print $2}')
IMAGES_TOTAL=$(echo "$DOCKER_INFO"     | awk '/^Images:/ {print $2}')
STORAGE_DRIVER=$(echo "$DOCKER_INFO"   | awk '/Storage Driver:/ {print $3}')

echo ""
echo -e "  Containers : ${BOLD}${CONTAINERS_TOTAL}${RESET} total  (${GREEN}${CONTAINERS_RUN} running${RESET} / ${RED}${CONTAINERS_STOP} stopped${RESET})"
echo -e "  Images     : ${BOLD}${IMAGES_TOTAL}${RESET}"
echo -e "  Storage    : ${BOLD}${STORAGE_DRIVER}${RESET}"

# ── Running Containers ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Running Containers ──────────────────────${RESET}"
RUNNING=$(docker ps --format "{{.Names}}" 2>/dev/null)
if [ -z "$RUNNING" ]; then
    echo -e "  ${YELLOW}[INFO]${RESET} No containers are currently running."
else
    docker ps --format "table  {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    echo ""
    echo -e "${BOLD}── Container Resource Usage (live stats) ───${RESET}"
    docker stats --no-stream --format \
        "table  {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
        2>/dev/null
fi

# ── Stopped Containers ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Stopped / Exited Containers ─────────────${RESET}"
STOPPED=$(docker ps -a --filter "status=exited" --filter "status=created" \
    --format "{{.Names}}" 2>/dev/null)
if [ -z "$STOPPED" ]; then
    echo -e "  ${GREEN}[  OK ]${RESET} No stopped containers."
else
    docker ps -a --filter "status=exited" --filter "status=created" \
        --format "table  {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.ExitCode}}" 2>/dev/null
    EXITED_COUNT=$(echo "$STOPPED" | wc -l)
    echo ""
    echo -e "  ${YELLOW}[INFO]${RESET} ${EXITED_COUNT} stopped container(s). Clean up with: docker container prune"
fi

# ── Docker Images ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Docker Images ───────────────────────────${RESET}"
docker images --format "table  {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" \
    2>/dev/null | head -20

# Dangling images
DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
if [ "$DANGLING" -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}[INFO]${RESET} ${DANGLING} dangling (untagged) image(s) found. Clean with: docker image prune"
fi

# ── Docker Volumes ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Docker Volumes ──────────────────────────${RESET}"
VOL_COUNT=$(docker volume ls -q 2>/dev/null | wc -l)
if [ "$VOL_COUNT" -eq 0 ]; then
    echo -e "  No volumes found."
else
    docker volume ls --format "table  {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}" 2>/dev/null
fi

# ── Docker Networks ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Docker Networks ─────────────────────────${RESET}"
docker network ls --format "table  {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null

# ── Disk Usage ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Docker Disk Usage ───────────────────────${RESET}"
docker system df 2>/dev/null

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Docker monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"