#!/bin/bash

# ==========================================
# Docker Install Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Installs Docker Engine and Docker Compose
#   on Ubuntu/Debian systems. Safe to re-run.
#
# Usage:
#   chmod +x scripts/install-docker.sh
#   sudo ./scripts/install-docker.sh
# ==========================================

set -e   # Exit on any error

RED="\e[0;31m" GREEN="\e[0;32m" YELLOW="\e[0;33m" CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Docker Installation Script${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Root check ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "  ${RED}[ERROR]${RESET} This script must be run as root."
    echo -e "         Run: sudo $0"
    exit 1
fi

# ── OS Detection ──────────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_NAME="$PRETTY_NAME"
else
    echo -e "  ${RED}[ERROR]${RESET} Cannot detect OS. Only Ubuntu/Debian supported."
    exit 1
fi

echo -e "  Detected OS: ${BOLD}${OS_NAME}${RESET}"

if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
    echo -e "  ${RED}[ERROR]${RESET} This script supports Ubuntu/Debian only."
    echo -e "         For other distros: https://docs.docker.com/engine/install/"
    exit 1
fi

# ── Check if Docker already installed ────────────────────────
if command -v docker &>/dev/null; then
    echo -e "\n  ${GREEN}[  OK  ]${RESET} Docker is already installed:"
    docker --version
    docker compose version 2>/dev/null || echo "  Docker Compose plugin not found"
    echo ""
    echo -e "  ${CYAN}[INFO]${RESET}  Docker already present. Skipping installation."
    echo -e "         To reinstall: sudo apt remove docker-ce && run this script again"
    exit 0
fi

# ── Remove old Docker packages ────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 1]${RESET} Removing old Docker packages..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# ── Install Prerequisites ─────────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 2]${RESET} Installing prerequisites..."
apt-get update -qq
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https

# ── Add Docker GPG key ────────────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 3]${RESET} Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# ── Add Docker repository ─────────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 4]${RESET} Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/${OS_ID} \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# ── Install Docker Engine ─────────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 5]${RESET} Installing Docker Engine..."
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ── Start and enable Docker ───────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 6]${RESET} Starting Docker service..."
systemctl enable docker
systemctl start docker

# ── Add user to docker group ──────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 7]${RESET} Adding user to docker group..."
ACTUAL_USER="${SUDO_USER:-$USER}"
if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    usermod -aG docker "$ACTUAL_USER"
    echo -e "  ${GREEN}[ OK ]${RESET}  User '${ACTUAL_USER}' added to docker group"
    echo -e "         ${YELLOW}[NOTE]${RESET} Log out and back in for group change to take effect"
    echo -e "         Or run: newgrp docker"
fi

# ── Verify installation ───────────────────────────────────────
echo ""
echo -e "  ${CYAN}[STEP 8]${RESET} Verifying installation..."
DOCKER_VERSION=$(docker --version)
COMPOSE_VERSION=$(docker compose version)

echo -e "  ${GREEN}[ OK ]${RESET}  ${DOCKER_VERSION}"
echo -e "  ${GREEN}[ OK ]${RESET}  ${COMPOSE_VERSION}"

# Run hello-world test
echo ""
echo -e "  ${CYAN}[TEST]${RESET}  Running Docker hello-world test..."
if docker run --rm hello-world 2>&1 | grep -q "Hello from Docker"; then
    echo -e "  ${GREEN}[ OK ]${RESET}  Docker is working correctly!"
else
    echo -e "  ${YELLOW}[WARN]${RESET} hello-world test had unexpected output (Docker may still work)"
fi

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  ${GREEN}${BOLD}Docker installation complete!${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "  1. Log out and back in (or run: newgrp docker)"
echo -e "  2. Start the monitoring stack:"
echo -e "     ${CYAN}cd docker/ && docker compose up -d${RESET}"
echo -e "  3. Access Grafana: ${CYAN}http://localhost:3000${RESET}  (admin / admin123)"
echo -e "  4. Access Prometheus: ${CYAN}http://localhost:9090${RESET}"
