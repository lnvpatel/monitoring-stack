#!/bin/bash

# ==========================================
# User Audit Script
# Author: Vatsalya Patel
# GitHub: https://github.com/lnvpatel
#
# Description:
#   Audits system user accounts, identifies
#   sudo-capable users, checks for insecure
#   configurations, and reviews login activity.
#   Essential for Linux security administration.
#
# Usage:
#   ./user-audit.sh
#   sudo ./user-audit.sh    (for full auth log access)
# ==========================================

RED="\e[0;31m" YELLOW="\e[0;33m" GREEN="\e[0;32m"
CYAN="\e[0;36m" BOLD="\e[1m" RESET="\e[0m"

echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "${BOLD}${CYAN}   User Security Audit Report${RESET}"
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  Hostname : $(hostname)"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
if [ "$EUID" -ne 0 ]; then
    echo -e "  ${YELLOW}[NOTE]${RESET}   Running without root. Some sections may be limited."
fi
echo ""

# ── Currently Logged-In Users ─────────────────────────────────────────────────
echo -e "${BOLD}── Currently Logged-In Users ───────────────${RESET}"
LOGGED_COUNT=$(who | wc -l)
if [ "$LOGGED_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}[ OK ]${RESET} No users currently logged in."
else
    printf "  %-15s %-10s %-20s %-s\n" "USER" "TTY" "LOGIN TIME" "FROM"
    echo "  -------------------------------------------------------"
    who 2>/dev/null | while read -r user tty date time from; do
        printf "  %-15s %-10s %-20s %-s\n" "$user" "$tty" "$date $time" "${from:-local}"
    done
fi

# ── All System Users ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── All System Users (/etc/passwd) ──────────${RESET}"
printf "  %-20s %-8s %-8s %-20s %-s\n" "USERNAME" "UID" "GID" "SHELL" "HOME"
echo "  ---------------------------------------------------------------"
while IFS=: read -r username pw uid gid gecos home shell; do
    # Classify by UID
    if [ "$uid" -eq 0 ]; then
        # root
        printf "  ${RED}%-20s %-8s %-8s %-20s %-s${RESET}\n" "$username" "$uid" "$gid" "$shell" "$home"
    elif [ "$uid" -ge 1000 ]; then
        # Regular user
        printf "  ${GREEN}%-20s %-8s %-8s %-20s %-s${RESET}\n" "$username" "$uid" "$gid" "$shell" "$home"
    elif [ "$shell" != "/usr/sbin/nologin" ] && [ "$shell" != "/bin/false" ] && \
         [ "$shell" != "/sbin/nologin" ] && [ "$uid" -gt 0 ]; then
        # System user with a login shell (potential security concern)
        printf "  ${YELLOW}%-20s %-8s %-8s %-20s %-s${RESET}\n" "$username" "$uid" "$gid" "$shell" "$home"
    fi
done < /etc/passwd | head -40

echo ""
echo -e "  ${CYAN}Legend:${RESET} ${RED}root${RESET}  ${GREEN}regular users (UID≥1000)${RESET}  ${YELLOW}system users with login shell${RESET}"

# ── Users with Login Shells ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Users with Interactive Login Shell ───────${RESET}"
INTERACTIVE_USERS=$(grep -v "nologin\|/bin/false" /etc/passwd | \
    awk -F: '$3 >= 1000 || $3 == 0 {print $1}')
echo -e "  ${BOLD}$(echo "$INTERACTIVE_USERS" | wc -l)${RESET} user(s) can log in interactively:"
echo "$INTERACTIVE_USERS" | while read -r u; do
    echo -e "  ${GREEN}  •  $u${RESET}"
done

# ── Sudo-Capable Users ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Sudo-Capable Users ──────────────────────${RESET}"
echo -e "  ${CYAN}[Members of sudo / wheel group]${RESET}"

for group in sudo wheel admin; do
    MEMBERS=$(getent group "$group" 2>/dev/null | cut -d: -f4 | tr ',' '\n')
    if [ -n "$MEMBERS" ]; then
        echo -e "\n  Group: ${BOLD}${group}${RESET}"
        echo "$MEMBERS" | while read -r m; do
            [ -n "$m" ] && echo -e "  ${RED}  ✗ sudo access: $m${RESET}"
        done
    fi
done

# Users with direct root in sudoers
if [ -r /etc/sudoers ]; then
    echo ""
    echo -e "  ${BOLD}Direct sudoers entries (non-group):${RESET}"
    grep -v "^#\|^$\|^Defaults\|^%" /etc/sudoers 2>/dev/null | head -20 | \
        while IFS= read -r line; do
            echo -e "  ${YELLOW}│${RESET} $line"
        done
else
    echo -e "\n  ${YELLOW}[INFO]${RESET} /etc/sudoers not readable without root."
fi

# ── Empty Passwords ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Security: Empty Passwords ───────────────${RESET}"
if [ -r /etc/shadow ]; then
    EMPTY_PW=$(awk -F: '($2 == "" || $2 == "!!" ) && $3 != "" {print $1}' /etc/shadow 2>/dev/null)
    if [ -z "$EMPTY_PW" ]; then
        echo -e "  ${GREEN}[  OK  ]${RESET}  No accounts with empty passwords."
    else
        echo -e "  ${RED}[ALERT]${RESET}  Accounts with empty/locked passwords:"
        echo "$EMPTY_PW" | while read -r u; do
            echo -e "  ${RED}│${RESET}  $u"
        done
    fi
else
    echo -e "  ${YELLOW}[INFO]${RESET} /etc/shadow not readable. Run with sudo."
fi

# ── UID 0 Accounts (root equivalents) ────────────────────────────────────────
echo ""
echo -e "${BOLD}── Security: Accounts with UID 0 ───────────${RESET}"
UID0_ACCOUNTS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd 2>/dev/null)
UID0_COUNT=$(echo "$UID0_ACCOUNTS" | wc -l)
if [ "$UID0_COUNT" -eq 1 ]; then
    echo -e "  ${GREEN}[  OK  ]${RESET}  Only 'root' has UID 0 — expected."
else
    echo -e "  ${RED}[ALERT]${RESET}  Multiple accounts with UID 0 (root equivalent):"
    echo "$UID0_ACCOUNTS" | while read -r u; do
        echo -e "  ${RED}│${RESET}  $u"
    done
fi

# ── Last Login for Each User ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Last Login per User ─────────────────────${RESET}"
printf "  %-20s %-s\n" "USERNAME" "LAST LOGIN"
echo "  -------------------------------------------------------"
while IFS=: read -r user _ uid _; do
    [ "$uid" -lt 1000 ] && [ "$uid" -ne 0 ] && continue
    LAST=$(lastlog -u "$user" 2>/dev/null | tail -1 | awk '{$1=""; print $0}' | xargs)
    printf "  %-20s %-s\n" "$user" "${LAST:-Never logged in}"
done < /etc/passwd | head -20

# ── SSH Authorized Keys Audit ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── SSH Authorized Keys Audit ───────────────${RESET}"
AUTH_KEY_FOUND=0
while IFS=: read -r user _ uid _ _ home _; do
    [ "$uid" -lt 1000 ] && [ "$uid" -ne 0 ] && continue
    KEY_FILE="${home}/.ssh/authorized_keys"
    if [ -f "$KEY_FILE" ] && [ -r "$KEY_FILE" ]; then
        KEY_COUNT=$(grep -vc "^#\|^$" "$KEY_FILE" 2>/dev/null || echo 0)
        echo -e "  ${YELLOW}[$KEY_COUNT key(s)]${RESET}  ${BOLD}${user}${RESET}  →  $KEY_FILE"
        AUTH_KEY_FOUND=1
    fi
done < /etc/passwd
[ "$AUTH_KEY_FOUND" -eq 0 ] && echo -e "  ${GREEN}[ OK ]${RESET}  No authorized_keys files found."

# ── Recent Failed SSH Logins ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Recent Failed SSH Logins (last 20) ───────${RESET}"
AUTH_LOG=""
for f in /var/log/auth.log /var/log/secure; do
    [ -r "$f" ] && AUTH_LOG="$f" && break
done

if [ -n "$AUTH_LOG" ]; then
    FAILS=$(grep "Failed password\|Invalid user" "$AUTH_LOG" 2>/dev/null | tail -20)
    FAIL_COUNT=$(grep -c "Failed password\|Invalid user" "$AUTH_LOG" 2>/dev/null || echo 0)
    echo -e "  Total failures in log : ${BOLD}${RED}${FAIL_COUNT}${RESET}"
    echo ""
    echo "$FAILS" | while IFS= read -r line; do
        echo -e "  ${YELLOW}│${RESET} $line"
    done
    if [ "$FAIL_COUNT" -gt 100 ]; then
        echo ""
        echo -e "  ${RED}[ALERT]${RESET} High SSH brute-force activity detected!"
        echo -e "  ${YELLOW}[TIP]${RESET}  Install fail2ban: sudo apt install fail2ban"
        echo -e "  ${YELLOW}[TIP]${RESET}  Disable password auth: PasswordAuthentication no in /etc/ssh/sshd_config"
    fi
else
    echo -e "  ${YELLOW}[INFO]${RESET}  Auth log not readable. Run with sudo."
fi

echo ""
echo -e "${BOLD}${CYAN}==========================================${RESET}"
echo -e "  User audit completed."
echo -e "  ${CYAN}TIP:${RESET} Run with 'sudo' for full security data."
echo -e "${BOLD}${CYAN}==========================================${RESET}"
