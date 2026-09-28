#!/bin/bash

# =====================================================
# Universal DDoS Defense Script - FULL PROTECTION
# Protejează TOATE porturile și TOATE protocoalele
# Compatibil cu: Debian, Ubuntu, RHEL, CentOS, Rocky, Alma, Fedora, Arch, SUSE
# =====================================================

set -euo pipefail
IFS=$'\n\t'

# Culori
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Variabile globale
DISTRO=""
PKG_MANAGER=""
TOTAL_RULES=0

# =====================================================
# Funcții utilitare
# =====================================================

print_status() {
    echo -e "${GREEN}[+]${RESET} $1"
}

print_error() {
    echo -e "${RED}[!]${RESET} $1" >&2
}

print_info() {
    echo -e "${BLUE}[*]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${RESET} $1"
}

print_header() {
    echo ""
    echo "========================================="
    echo -e "${CYAN}$1${RESET}"
    echo "========================================="
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        exit 1
    fi
    print_status "Running as root"
}

# =====================================================
# Detectare distribuție
# =====================================================

detect_distro() {
    print_info "Detecting Linux distribution..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
    elif [[ -f /etc/SuSE-release ]]; then
        DISTRO="suse"
    else
        print_error "Unsupported Linux distribution!"
        exit 1
    fi
    
    print_status "Detected: $DISTRO"
    
    # Set package manager
    case $DISTRO in
        ubuntu|debian|linuxmint|pop|kali|raspbian)
            PKG_MANAGER="apt-get"
            ;;
        rhel|centos|fedora|rocky|almalinux|ol)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        arch|manjaro|endeavouros)
            PKG_MANAGER="pacman"
            ;;
        suse|opensuse)
            PKG_MANAGER="zypper"
            ;;
        alpine)
            PKG_MANAGER="apk"
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
    
    print_status "Package manager: $PKG_MANAGER"
}

# =====================================================
# Instalare pachete
# =====================================================

install_packages() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        return 0
    fi
    
    print_info "Installing packages: ${to_install[*]}"
    
    case $PKG_MANAGER in
        apt-get)
            apt-get update -y &>/dev/null || true
            apt-get install -y "${to_install[@]}" &>/dev/null || {
                print_error "Failed to install packages"
                return 1
            }
            ;;
        dnf|yum)
            $PKG_MANAGER install -y "${to_install[@]}" &>/dev/null || {
                print_error "Failed to install packages"
                return 1
            }
            ;;
        pacman)
            pacman -Sy --noconfirm "${to_install[@]}" &>/dev/null || {
                print_error "Failed to install packages"
                return 1
            }
            ;;
        zypper)
            zypper refresh &>/dev/null || true
            zypper install -y "${to_install[@]}" &>/dev/null || {
                print_error "Failed to install packages"
                return 1
            }
            ;;
        apk)
            apk update &>/dev/null || true
            apk add "${to_install[@]}" &>/dev/null || {
                print_error "Failed to install packages"
                return 1
            }
            ;;
    esac
    
    print_status "Packages installed successfully"
}

# =====================================================
# Salvare reguli iptables
# =====================================================

save_iptables_rules() {
    print_info "Saving iptables rules..."
    
    case $DISTRO in
        ubuntu|debian|linuxmint|pop|kali|raspbian)
            if ! command -v netfilter-persistent &>/dev/null; then
                install_packages iptables-persistent
            fi
            netfilter-persistent save 2>/dev/null || true
            ;;
        rhel|centos|fedora|rocky|almalinux|ol)
            mkdir -p /etc/sysconfig
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            ;;
        arch|manjaro|endeavouros)
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/iptables.rules 2>/dev/null || true
            ;;
        suse|opensuse)
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            ;;
        alpine)
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules-save 2>/dev/null || true
            ;;
    esac
    
    print_status "iptables rules saved permanently"
}

# =====================================================
# Protecție iptables completă
# =====================================================

iptables_full_protection() {
    print_header "SETTING UP COMPLETE DDoS PROTECTION"
    
    # Verifică iptables
    if ! command -v iptables &>/dev/null; then
        install_packages iptables
    fi
    
    # Backup reguli existente
    local backup_file="/tmp/iptables-backup-$(date +%Y%m%d-%H%M%S).rules"
    iptables-save > "$backup_file" 2>/dev/null || true
    print_info "Backup saved to $backup_file"
    
    # Reset chains existente
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    
    # =====================================================
    # 1. Politici de bază
    # =====================================================
    print_info "Setting default policies..."
    
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    TOTAL_RULES=$((TOTAL_RULES + 6))
    
    # =====================================================
    # 2. SYN Flood Protection
    # =====================================================
    print_info "Enabling SYN flood protection..."
    iptables -A INPUT -p tcp --syn -m limit --limit 1000/second --limit-burst 2000 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    TOTAL_RULES=$((TOTAL_RULES + 2))
    
    # =====================================================
    # 3. UDP Flood Protection
    # =====================================================
    print_info "Enabling UDP flood protection..."
    iptables -A INPUT -p udp -m limit --limit 50/second --limit-burst 100 -j ACCEPT
    iptables -A INPUT -p udp -j DROP
    TOTAL_RULES=$((TOTAL_RULES + 2))
    
    # =====================================================
    # 4. ICMP Flood Protection
    # =====================================================
    print_info "Enabling ICMP flood protection..."
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/second --limit-burst 10 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    TOTAL_RULES=$((TOTAL_RULES + 2))
    
    # =====================================================
    # 5. Port Scanning Protection
    # =====================================================
    print_info "Enabling port scanning protection..."
    iptables -N PORT_SCAN 2>/dev/null || true
    iptables -F PORT_SCAN 2>/dev/null || true
    iptables -A PORT_SCAN -m recent --set --name PORTSCAN
    iptables -A PORT_SCAN -m recent --update --seconds 60 --hitcount 10 --name PORTSCAN -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j PORT_SCAN
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j PORT_SCAN
    TOTAL_RULES=$((TOTAL_RULES + 5))
    
    # =====================================================
    # 6. Invalid Packet Drop
    # =====================================================
    print_info "Dropping invalid packets..."
    iptables -A INPUT -m state --state INVALID -j DROP
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    # =====================================================
    # 7. Connection Limiting per IP
    # =====================================================
    print_info "Setting connection limits per IP..."
    iptables -A INPUT -p tcp -m connlimit --connlimit-above 100 --connlimit-mask 32 -j DROP
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    # =====================================================
    # 8. Rate Limiting pentru conexiuni noi
    # =====================================================
    print_info "Setting rate limiting for new connections..."
    iptables -A INPUT -p tcp -m state --state NEW -m limit --limit 200/minute --limit-burst 300 -j ACCEPT
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    # =====================================================
    # 9. Protecție HTTP/HTTPS flood
    # =====================================================
    print_info "Enabling HTTP/HTTPS flood protection..."
    iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set --name HTTP 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 10 --hitcount 20 --name HTTP -j DROP 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 443 -m state --state NEW -m recent --set --name HTTPS 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 443 -m state --state NEW -m recent --update --seconds 10 --hitcount 20 --name HTTPS -j DROP 2>/dev/null || true
    TOTAL_RULES=$((TOTAL_RULES + 4))
    
    # =====================================================
    # 10. Protecție SSH brute force
    # =====================================================
    print_info "Enabling SSH brute force protection..."
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 5 --name SSH -j DROP 2>/dev/null || true
    TOTAL_RULES=$((TOTAL_RULES + 2))
    
    # =====================================================
    # 11. Fragment Attack Protection
    # =====================================================
    print_info "Enabling fragment attack protection..."
    iptables -A INPUT -f -j DROP 2>/dev/null || true
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    # =====================================================
    # 12. XMAS Attack Protection
    # =====================================================
    print_info "Enabling XMAS attack protection..."
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    # =====================================================
    # 13. Logging pentru atacuri
    # =====================================================
    print_info "Setting up attack logging..."
    iptables -N LOG_DROP 2>/dev/null || true
    iptables -F LOG_DROP 2>/dev/null || true
    iptables -A LOG_DROP -m limit --limit 10/minute -j LOG --log-prefix "[DDoS-ATTACK] " --log-level 4
    iptables -A LOG_DROP -j DROP
    iptables -A INPUT -j LOG_DROP
    TOTAL_RULES=$((TOTAL_RULES + 3))
    
    print_status "iptables rules applied - TOTAL: $TOTAL_RULES rules"
    
    # Salvare reguli
    save_iptables_rules
}

# =====================================================
# Configurare kernel parameters
# =====================================================

kernel_tuning() {
    print_header "KERNEL PARAMETERS TUNING"
    
    print_info "Optimizing kernel parameters for DDoS protection..."
    
    # Backup sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.backup 2>/dev/null || true
    
    # Adaugă setările doar dacă nu există deja
    if ! grep -q "DDoS Protection Settings" /etc/sysctl.conf; then
        cat >> /etc/sysctl.conf << 'EOF'

# DDoS Protection Settings
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 1024
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ratelimit = 100
EOF
    fi
    
    sysctl -p &>/dev/null || true
    
    print_status "Kernel parameters optimized"
}

# =====================================================
# UFW hardening
# =====================================================

ufw_full_protection() {
    if [[ "$DISTRO" != "ubuntu" && "$DISTRO" != "debian" && "$DISTRO" != "linuxmint" && "$DISTRO" != "pop" ]]; then
        print_warning "UFW not standard on $DISTRO, skipping"
        return 0
    fi
    
    print_info "Configuring UFW for full protection..."
    
    if ! command -v ufw &>/dev/null; then
        install_packages ufw
    fi
    
    # Reset UFW
    ufw --force disable 2>/dev/null || true
    
    # Setează politici
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permite serviciile comune
    ufw allow 22/tcp comment "SSH" 2>/dev/null || true
    ufw allow 80/tcp comment "HTTP" 2>/dev/null || true
    ufw allow 443/tcp comment "HTTPS" 2>/dev/null || true
    
    # Rate limiting pentru SSH
    ufw limit 22/tcp 2>/dev/null || true
    
    # Activează logging
    ufw logging on 2>/dev/null || true
    
    # Activează UFW
    echo "y" | ufw enable 2>/dev/null || true
    
    print_status "UFW configured - Outgoing connections allowed"
}

# =====================================================
# Fail2ban setup
# =====================================================

fail2ban_full_setup() {
    print_header "FAIL2BAN SETUP"
    
    if ! command -v fail2ban-client &>/dev/null; then
        install_packages fail2ban
    fi
    
    # Creează directorul
    mkdir -p /etc/fail2ban/jail.d
    
    # Creează jail local
    cat > /etc/fail2ban/jail.d/full_ddos_protection.conf << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

    # Restart fail2ban
    systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true
    systemctl enable fail2ban 2>/dev/null || true
    
    print_status "Fail2ban configured"
}

# =====================================================
# Configurare Nginx anti-DDoS
# =====================================================

nginx_full_protection() {
    if ! command -v nginx &>/dev/null; then
        print_warning "Nginx not installed, skipping Nginx protection"
        return 0
    fi
    
    print_header "NGINX DDoS PROTECTION"
    
    local nginx_conf_dir="/etc/nginx/conf.d"
    mkdir -p "$nginx_conf_dir"
    
    cat > "$nginx_conf_dir/ddos_full_protection.conf" << 'EOF'
limit_req_zone $binary_remote_addr zone=ddos_protection:10m rate=10r/m;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

client_body_timeout 5s;
client_header_timeout 5s;
send_timeout 10s;
keepalive_timeout 10s;
client_max_body_size 1m;

limit_conn conn_limit 10;
limit_req zone=ddos_protection burst=20 nodelay;
EOF

    # Testează configurația
    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
        print_status "Nginx DDoS protection enabled"
    else
        print_warning "Nginx configuration test failed, skipping"
        rm -f "$nginx_conf_dir/ddos_full_protection.conf" 2>/dev/null || true
    fi
}

# =====================================================
# Monitorizare
# =====================================================

setup_full_monitoring() {
    print_header "SETTING UP MONITORING"
    
    # Script de monitorizare
    cat > /usr/local/bin/ddos-monitor-full << 'EOF'
#!/bin/bash
while true; do
    clear
    echo "========================================="
    echo "     COMPLETE DDoS PROTECTION MONITOR"
    echo "========================================="
    echo "Time: $(date)"
    echo "Uptime: $(uptime)"
    echo ""
    echo "=== SYSTEM STATUS ==="
    echo "Load Average: $(cat /proc/loadavg)"
    echo "Memory Usage: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo "Active Connections: $(ss -tun 2>/dev/null | wc -l)"
    echo "iptables Rules: $(iptables -L -n 2>/dev/null | wc -l)"
    echo ""
    echo "=== RECENT ATTACKS ==="
    dmesg | grep -i "DDoS-ATTACK" | tail -5 2>/dev/null || echo "No attacks detected"
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 10
done
EOF
    
    chmod +x /usr/local/bin/ddos-monitor-full 2>/dev/null || true
    
    print_status "Monitoring system installed"
    print_info "Run: /usr/local/bin/ddos-monitor-full for real-time monitoring"
}

# =====================================================
# Afișare status
# =====================================================

show_full_status() {
    print_header "CURRENT PROTECTION STATUS"
    
    echo -e "\n${CYAN}=== SYSTEM INFO ===${RESET}"
    echo "Distribution: $DISTRO"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    
    echo -e "\n${CYAN}=== IPTABLES RULES ===${RESET}"
    iptables -L INPUT -n -v 2>/dev/null | head -20 || echo "No iptables rules"
    echo "Total rules: $(iptables -L INPUT -n 2>/dev/null | wc -l)"
    
    echo -e "\n${CYAN}=== CONNECTION STATISTICS ===${RESET}"
    echo "Active connections: $(ss -tun 2>/dev/null | wc -l)"
    
    echo -e "\n${CYAN}=== KERNEL PARAMETERS ===${RESET}"
    sysctl net.ipv4.tcp_syncookies 2>/dev/null || echo "Not available"
    sysctl net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo "Not available"
}

# =====================================================
# Reset complet
# =====================================================

reset_full() {
    print_warning "RESETTING ALL PROTECTIONS"
    
    read -p "Are you sure? Type 'YES' to continue: " confirm
    if [[ "$confirm" != "YES" ]]; then
        print_status "Reset cancelled"
        return 0
    fi
    
    # Reset iptables
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    
    # Set policy implicită ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Elimină configurații Nginx
    rm -f /etc/nginx/conf.d/ddos_full_protection.conf 2>/dev/null || true
    
    # Oprește fail2ban
    systemctl stop fail2ban 2>/dev/null || true
    systemctl disable fail2ban 2>/dev/null || true
    
    # Dezactivează UFW
    if command -v ufw &>/dev/null; then
        ufw --force disable 2>/dev/null || true
    fi
    
    print_status "All protections removed"
    print_warning "System is now unprotected!"
}

# =====================================================
# Aplică TOATE protecțiile
# =====================================================

apply_full_protection() {
    print_header "DEPLOYING COMPLETE DDoS PROTECTION"
    print_info "This will protect against:"
    echo "  • SYN Flood"
    echo "  • UDP Flood"
    echo "  • ICMP/Ping Flood"
    echo "  • HTTP/HTTPS Flood"
    echo "  • Port Scanning"
    echo "  • XMAS Attacks"
    echo "  • Fragment Attacks"
    echo "  • Brute Force Attacks"
    echo ""
    
    sleep 2
    
    iptables_full_protection
    kernel_tuning
    ufw_full_protection
    fail2ban_full_setup
    nginx_full_protection
    setup_full_monitoring
    
    print_header "DEPLOYMENT COMPLETE"
    print_status "ALL DDoS PROTECTIONS ARE NOW ACTIVE!"
    print_status "Outgoing connections: FULLY ALLOWED"
    print_status "Incoming protection: ACTIVE ON ALL PORTS"
    
    show_full_status
    
    echo ""
    print_info "To monitor in real-time: /usr/local/bin/ddos-monitor-full"
    print_info "To reset all protections: Run this script and select reset option"
}

# =====================================================
# Meniu principal
# =====================================================

main() {
    check_root
    detect_distro
    
    echo ""
    echo "========================================="
    echo -e "${GREEN}COMPLETE DDoS DEFENSE SYSTEM${RESET}"
    echo "========================================="
    echo "1) Apply FULL DDoS Protection (RECOMMENDED)"
    echo "2) Show current status"
    echo "3) Reset all protections"
    echo "4) Exit"
    echo "========================================="
    
    read -p "Select [1-4]: " CHOICE
    
    case "$CHOICE" in
        1)
            apply_full_protection
            ;;
        2)
            show_full_status
            ;;
        3)
            reset_full
            ;;
        4)
            print_status "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

# =====================================================
# Rulează main
# =====================================================

main "$@"