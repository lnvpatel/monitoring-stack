#!/bin/bash

# ==========================================
# Service Monitoring Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Checks operational status of critical
#   Linux services. Shows active/inactive
#   state, enabled/disabled at boot,
#   uptime, and last journal lines for
#   any failing services.
#
# Usage:
#   ./service-monitor.sh
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

# ── Services to monitor ────────────────────────────────────────────────────────
# Group 1: Core OS services
CORE_SERVICES=("ssh" "cron" "rsyslog" "systemd-journald" "ufw")

# Group 2: Security services
SECURITY_SERVICES=("fail2ban" "apparmor" "auditd")

# Group 3: Web / App services
APP_SERVICES=("nginx" "apache2" "mysql" "postgresql" "redis-server")

# Group 4: Cloud / DevOps tools
DEVOPS_SERVICES=("docker" "containerd" "prometheus" "node_exporter" "grafana-server")

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   Linux Service Monitoring Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Helper: check one service ──────────────────────────────────────────────────
RUNNING_COUNT=0
FAILED_COUNT=0
NOT_INSTALLED_COUNT=0

check_service() {
    local svc="$1"

    # Check if the unit file exists at all
    if ! systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1 || \
       ! systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "${svc}"; then
        echo -e "  ${CYAN}[NOT INSTALLED]${RESET}  ${BOLD}${svc}${RESET}"
        NOT_INSTALLED_COUNT=$((NOT_INSTALLED_COUNT + 1))
        return
    fi

    local is_active
    local is_enabled
    is_active=$(systemctl is-active "$svc" 2>/dev/null)
    is_enabled=$(systemctl is-enabled "$svc" 2>/dev/null)

    # Service uptime from ExecMainStartTimestamp
    local uptime_str=""
    local start_time
    start_time=$(systemctl show "$svc" --property=ExecMainStartTimestamp \
        --value 2>/dev/null | grep -v "^$")
    if [ -n "$start_time" ] && [ "$start_time" != "n/a" ]; then
        uptime_str="  (started: $start_time)"
    fi

    if [ "$is_active" = "active" ]; then
        echo -e "  ${GREEN}[ RUNNING ]${RESET}  ${BOLD}${svc}${RESET}   enabled: ${is_enabled}${uptime_str}"
        RUNNING_COUNT=$((RUNNING_COUNT + 1))
    elif [ "$is_active" = "inactive" ]; then
        if [ "$is_enabled" = "enabled" ]; then
            echo -e "  ${YELLOW}[ INACTIVE ]${RESET} ${BOLD}${svc}${RESET}   enabled at boot – but NOT running"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        else
            echo -e "  ${YELLOW}[ STOPPED  ]${RESET} ${BOLD}${svc}${RESET}   disabled (not expected to run)"
        fi
    elif [ "$is_active" = "failed" ]; then
        echo -e "  ${RED}[  FAILED  ]${RESET} ${BOLD}${svc}${RESET}   enabled: ${is_enabled}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        # Show last journal entries for failed service
        echo -e "  ${RED}  Last journal entries:${RESET}"
        journalctl -u "$svc" -n 3 --no-pager 2>/dev/null | \
            while IFS= read -r jline; do echo -e "    ${RED}│${RESET} $jline"; done
        echo -e "  ${YELLOW}  Fix: sudo systemctl restart ${svc}${RESET}"
    else
        echo -e "  ${YELLOW}[ UNKNOWN  ]${RESET} ${BOLD}${svc}${RESET}  status: ${is_active}"
    fi
}

# ── Core OS Services ───────────────────────────────────────────────────────────
echo -e "${BOLD}── Core OS Services ────────────────────────${RESET}"
for svc in "${CORE_SERVICES[@]}"; do
    check_service "$svc"
done

# ── Security Services ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Security Services ───────────────────────${RESET}"
for svc in "${SECURITY_SERVICES[@]}"; do
    check_service "$svc"
done

# ── Web / Application Services ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Web / Application Services ──────────────${RESET}"
for svc in "${APP_SERVICES[@]}"; do
    check_service "$svc"
done

# ── DevOps / Cloud Services ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── DevOps / Cloud Services ─────────────────${RESET}"
for svc in "${DEVOPS_SERVICES[@]}"; do
    check_service "$svc"
done

# ── Failed Services System-Wide ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}── All Failed Units (system-wide) ──────────${RESET}"
SYSTEM_FAILED=$(systemctl list-units --state=failed --no-legend 2>/dev/null)
if [ -z "$SYSTEM_FAILED" ]; then
    echo -e "  ${GREEN}[  OK  ]${RESET}  No failed systemd units found."
else
    echo "$SYSTEM_FAILED" | while IFS= read -r line; do
        echo -e "  ${RED}[FAILED]${RESET}  $line"
    done
    echo ""
    echo -e "  ${YELLOW}[TIP]${RESET} Run 'systemctl --failed' for full details"
    echo -e "  ${YELLOW}[TIP]${RESET} Run 'journalctl -xe' to see error logs"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  ${GREEN}Running  :${RESET} ${BOLD}${RUNNING_COUNT}${RESET} service(s)"
echo -e "  ${RED}Failed   :${RESET} ${BOLD}${FAILED_COUNT}${RESET} service(s) with issues"
echo -e "  ${CYAN}N/A      :${RESET} ${BOLD}${NOT_INSTALLED_COUNT}${RESET} not installed on this system"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Service monitoring completed."
echo -e "${BOLD}${CYAN}==========================================${RESET}"