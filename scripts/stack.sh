#!/bin/bash

# ==========================================
# Monitoring Stack Manager Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Manages the full Prometheus + Grafana +
#   Node Exporter + Alertmanager stack.
#   Wraps docker compose with status checks.
#
# Usage:
#   ./scripts/stack.sh start
#   ./scripts/stack.sh stop
#   ./scripts/stack.sh status
#   ./scripts/stack.sh restart
#   ./scripts/stack.sh logs [service]
#   ./scripts/stack.sh health
# ==========================================

set -e

RED="\e[0;31m" GREEN="\e[0;32m" YELLOW="\e[0;33m" CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/docker"

COMMAND="${1:-help}"

# ── Check docker is installed ─────────────────────────────────
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "  ${RED}[ERROR]${RESET} Docker is not installed."
        echo -e "         Run: sudo ./scripts/install-docker.sh"
        exit 1
    fi
    if ! docker compose version &>/dev/null; then
        echo -e "  ${RED}[ERROR]${RESET} Docker Compose plugin not found."
        echo -e "         Install with: sudo apt install docker-compose-plugin"
        exit 1
    fi
}

banner() {
    echo -e "${BOLD}${CYAN}==========================================${RESET}"
    echo -e "${BOLD}${CYAN}   Monitoring Stack Manager${RESET}"
    echo -e "${BOLD}${CYAN}==========================================${RESET}"
    echo -e "  Command  : ${BOLD}${COMMAND}${RESET}"
    echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
}

# ── start ─────────────────────────────────────────────────────
cmd_start() {
    banner
    check_docker
    echo -e "  ${CYAN}[INFO]${RESET}  Starting all monitoring services..."
    cd "$DOCKER_DIR"
    docker compose up -d
    echo ""
    echo -e "  ${GREEN}[ OK ]${RESET}  Stack started. Waiting 5s for services to be ready..."
    sleep 5
    cmd_status
    echo ""
    echo -e "  ${BOLD}Access points:${RESET}"
    echo -e "  ${GREEN}Prometheus   ${RESET}→  http://localhost:9090"
    echo -e "  ${GREEN}Grafana      ${RESET}→  http://localhost:3000  (admin / admin123)"
    echo -e "  ${GREEN}Node Export  ${RESET}→  http://localhost:9100/metrics"
    echo -e "  ${GREEN}Alertmanager ${RESET}→  http://localhost:9093"
}

# ── stop ──────────────────────────────────────────────────────
cmd_stop() {
    banner
    check_docker
    echo -e "  ${YELLOW}[INFO]${RESET}  Stopping all monitoring services..."
    cd "$DOCKER_DIR"
    docker compose down
    echo -e "  ${GREEN}[ OK ]${RESET}  All services stopped. Data volumes preserved."
}

# ── restart ───────────────────────────────────────────────────
cmd_restart() {
    banner
    check_docker
    echo -e "  ${CYAN}[INFO]${RESET}  Restarting all monitoring services..."
    cd "$DOCKER_DIR"
    docker compose restart
    echo ""
    sleep 3
    cmd_status
}

# ── status ────────────────────────────────────────────────────
cmd_status() {
    check_docker
    echo -e "${BOLD}── Service Status ──────────────────────────${RESET}"
    cd "$DOCKER_DIR"
    docker compose ps
    echo ""

    # Health check for each endpoint
    echo -e "${BOLD}── Endpoint Health ─────────────────────────${RESET}"
    check_endpoint() {
        local name="$1" url="$2"
        if curl -fs --max-time 3 "$url" -o /dev/null 2>/dev/null; then
            echo -e "  ${GREEN}[ UP ]${RESET}  ${name}  →  ${url}"
        else
            echo -e "  ${RED}[DOWN]${RESET}  ${name}  →  ${url}"
        fi
    }

    check_endpoint "Prometheus   " "http://localhost:9090/-/healthy"
    check_endpoint "Grafana      " "http://localhost:3000/api/health"
    check_endpoint "Node Exporter" "http://localhost:9100/metrics"
    check_endpoint "Alertmanager " "http://localhost:9093/-/healthy"
}

# ── logs ──────────────────────────────────────────────────────
cmd_logs() {
    check_docker
    SERVICE="${2:-}"
    cd "$DOCKER_DIR"
    if [ -n "$SERVICE" ]; then
        echo -e "${BOLD}${CYAN}── Logs: ${SERVICE} ──────────────────────────${RESET}"
        docker compose logs -f --tail=100 "$SERVICE"
    else
        echo -e "${BOLD}${CYAN}── All Service Logs ────────────────────────${RESET}"
        docker compose logs -f --tail=50
    fi
}

# ── health ────────────────────────────────────────────────────
cmd_health() {
    banner
    cmd_status
}

# ── pull (update images) ──────────────────────────────────────
cmd_pull() {
    banner
    check_docker
    echo -e "  ${CYAN}[INFO]${RESET}  Pulling latest images..."
    cd "$DOCKER_DIR"
    docker compose pull
    echo -e "  ${GREEN}[ OK ]${RESET}  Images updated. Run './scripts/stack.sh restart' to apply."
}

# ── help ──────────────────────────────────────────────────────
cmd_help() {
    echo -e "${BOLD}${CYAN}==========================================${RESET}"
    echo -e "${BOLD}${CYAN}   Monitoring Stack Manager – Help${RESET}"
    echo -e "${BOLD}${CYAN}==========================================${RESET}"
    echo ""
    echo -e "  Usage: ${BOLD}./scripts/stack.sh <command> [service]${RESET}"
    echo ""
    echo -e "  ${BOLD}Commands:${RESET}"
    echo -e "    ${CYAN}start${RESET}           Start all services (Prometheus, Grafana, Node Exporter, Alertmanager)"
    echo -e "    ${CYAN}stop${RESET}            Stop all services (data volumes preserved)"
    echo -e "    ${CYAN}restart${RESET}         Restart all services"
    echo -e "    ${CYAN}status${RESET}          Show service status + endpoint health"
    echo -e "    ${CYAN}health${RESET}          Same as status"
    echo -e "    ${CYAN}logs${RESET}            Tail logs for all services"
    echo -e "    ${CYAN}logs <service>${RESET}  Tail logs for specific service"
    echo -e "    ${CYAN}pull${RESET}            Pull latest Docker images"
    echo -e "    ${CYAN}help${RESET}            Show this help"
    echo ""
    echo -e "  ${BOLD}Services:${RESET}  prometheus | grafana | node-exporter | alertmanager"
    echo ""
    echo -e "  ${BOLD}Access:${RESET}"
    echo -e "    Prometheus    → http://localhost:9090"
    echo -e "    Grafana       → http://localhost:3000  (admin / admin123)"
    echo -e "    Node Exporter → http://localhost:9100/metrics"
    echo -e "    Alertmanager  → http://localhost:9093"
}

# ── Dispatch ──────────────────────────────────────────────────
case "$COMMAND" in
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    status)   banner; cmd_status ;;
    health)   cmd_health ;;
    logs)     cmd_logs "$@" ;;
    pull)     cmd_pull ;;
    help|--help|-h|"") cmd_help ;;
    *)
        echo -e "  ${RED}[ERROR]${RESET} Unknown command: ${COMMAND}"
        echo ""
        cmd_help
        exit 1
        ;;
esac
