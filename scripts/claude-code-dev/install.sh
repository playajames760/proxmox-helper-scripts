#!/usr/bin/env bash

# Proxmox Helper Scripts - Claude Code Development Environment
# Part of the Personal Proxmox Helper Scripts Collection
# 
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh)

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="Claude Code Development Environment"
readonly SCRIPT_VERSION="1.0.0"
readonly GITHUB_REPO="playajames760/proxmox-helper-scripts"
readonly GITHUB_BRANCH="main"
readonly BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/claude-code-dev"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Default configuration
CT_ID=""
CT_NAME="claude-code-dev"
CT_CORES="4"
CT_RAM="8192"
CT_DISK="20"
CT_STORAGE="local-lvm"
INSTALL_VSCODE="yes"
INSTALL_TEMPLATES="yes"
CREATE_DEV_VOLUME="yes"
DEV_VOLUME_SIZE="50"

# Helper functions
msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

header() {
    clear
    cat << 'EOF'
   _____ _                 _        _____          _      
  / ____| |               | |      / ____|        | |     
 | |    | | __ _ _   _  __| | ___ | |     ___   __| | ___ 
 | |    | |/ _` | | | |/ _` |/ _ \| |    / _ \ / _` |/ _ \
 | |____| | (_| | |_| | (_| |  __/| |___| (_) | (_| |  __/
  \_____|_|\__,_|\__,_|\__,_|\___| \_____\___/ \__,_|\___|
                                                          
        Proxmox Helper Scripts Collection
     Claude Code Development Environment v1.0.0
EOF
    echo ""
    echo -e "${CYAN}Part of Personal Proxmox Helper Scripts${NC}"
    echo -e "${WHITE}https://github.com/${GITHUB_REPO}${NC}"
    echo ""
}

# Application metadata
app="Claude Code Dev Environment"
var_tags="development;ai;claude;nodejs;vscode"
var_cpu="4"
var_ram="8192"
var_disk="20"
var_os="ubuntu"
var_version="22.04"
var_unprivileged="1"

# Validation functions
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "This script must be run as root"
    fi
}

check_proxmox() {
    if ! command -v pveversion >/dev/null 2>&1; then
        msg_error "This script must be run on a Proxmox VE host"
    fi
    
    local pve_version
    pve_version=$(pveversion | grep "pve-manager" | cut -d'/' -f2 | cut -d'-' -f1)
    local major_version
    major_version=$(echo "$pve_version" | cut -d'.' -f1)
    
    if [[ $major_version -lt 8 ]]; then
        msg_warn "Proxmox VE $pve_version detected. Version 8.0+ recommended."
    else
        msg_ok "Proxmox VE $pve_version is supported"
    fi
}

get_next_vmid() {
    local next_id=200
    while pct status "$next_id" &>/dev/null; do
        ((next_id++))
    done
    echo "$next_id"
}

get_storage_pools() {
    pvesm status -content rootdir | awk 'NR>1 {print $1}' | head -1
}

# Interactive configuration
configure_basic() {
    header
    echo -e "${CYAN}Basic Configuration${NC}"
    echo ""
    
    # Container ID
    while true; do
        local default_id
        default_id=$(get_next_vmid)
        read -p "Container ID [$default_id]: " CT_ID
        CT_ID=${CT_ID:-$default_id}
        
        if [[ ! $CT_ID =~ ^[0-9]+$ ]]; then
            msg_error "Container ID must be a number"
            continue
        fi
        
        if pct status "$CT_ID" &>/dev/null; then
            msg_error "Container ID $CT_ID already exists"
            continue
        fi
        
        break
    done
    
    # Container name
    read -p "Container name [$CT_NAME]: " input
    CT_NAME=${input:-$CT_NAME}
    
    # Resources
    read -p "CPU cores [$CT_CORES]: " input
    CT_CORES=${input:-$CT_CORES}
    
    read -p "RAM in MB [$CT_RAM]: " input
    CT_RAM=${input:-$CT_RAM}
    
    read -p "Disk size in GB [$CT_DISK]: " input
    CT_DISK=${input:-$CT_DISK}
    
    # Storage
    local available_storage
    available_storage=$(get_storage_pools)
    read -p "Storage pool [$available_storage]: " input
    CT_STORAGE=${input:-$available_storage}
    
    # Optional features
    echo ""
    echo -e "${CYAN}Optional Features${NC}"
    
    read -p "Install VS Code Server? [Y/n]: " input
    case ${input,,} in
        n|no) INSTALL_VSCODE="no" ;;
        *) INSTALL_VSCODE="yes" ;;
    esac
    
    read -p "Install project templates? [Y/n]: " input
    case ${input,,} in
        n|no) INSTALL_TEMPLATES="no" ;;
        *) INSTALL_TEMPLATES="yes" ;;
    esac
    
    read -p "Create development volume (${DEV_VOLUME_SIZE}GB)? [Y/n]: " input
    case ${input,,} in
        n|no) CREATE_DEV_VOLUME="no" ;;
        *) CREATE_DEV_VOLUME="yes" ;;
    esac
}

show_config() {
    header
    echo -e "${CYAN}Configuration Summary${NC}"
    echo ""
    echo -e "Container ID: ${WHITE}$CT_ID${NC}"
    echo -e "Container Name: ${WHITE}$CT_NAME${NC}"
    echo -e "CPU Cores: ${WHITE}$CT_CORES${NC}"
    echo -e "RAM: ${WHITE}$CT_RAM MB${NC}"
    echo -e "Disk: ${WHITE}$CT_DISK GB${NC}"
    echo -e "Storage: ${WHITE}$CT_STORAGE${NC}"
    echo -e "VS Code Server: ${WHITE}$INSTALL_VSCODE${NC}"
    echo -e "Project Templates: ${WHITE}$INSTALL_TEMPLATES${NC}"
    echo -e "Development Volume: ${WHITE}$CREATE_DEV_VOLUME${NC}"
    echo ""
    
    read -p "Proceed with installation? [Y/n]: " input
    case ${input,,} in
        n|no) msg_error "Installation cancelled" ;;
    esac
}

# Container creation
create_container() {
    msg_info "Creating LXC container"
    
    # Download Ubuntu template if not available
    local template_path="/var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    if [[ ! -f "$template_path" ]]; then
        msg_info "Downloading Ubuntu 22.04 template"
        pveam update
        pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    fi
    
    # Create container
    pct create "$CT_ID" "$template_path" \
        --hostname "$CT_NAME" \
        --cores "$CT_CORES" \
        --memory "$CT_RAM" \
        --rootfs "${CT_STORAGE}:${CT_DISK}" \
        --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp,type=veth \
        --unprivileged 1 \
        --features keyctl=1,nesting=1,fuse=1 \
        --ostype ubuntu \
        --onboot 1 \
        --start 1
    
    msg_ok "Container created with ID $CT_ID"
    
    # Create development volume
    if [[ "$CREATE_DEV_VOLUME" == "yes" ]]; then
        msg_info "Creating development volume"
        pct set "$CT_ID" -mp0 "${CT_STORAGE}:${DEV_VOLUME_SIZE},mp=/opt/development"
        msg_ok "Development volume created"
    fi
}

# Wait for container to be ready
wait_for_container() {
    msg_info "Waiting for container to be ready"
    
    local timeout=60
    local count=0
    
    while ! pct exec "$CT_ID" -- test -f /bin/bash 2>/dev/null; do
        if [[ $count -ge $timeout ]]; then
            msg_error "Container failed to become ready within $timeout seconds"
        fi
        sleep 1
        ((count++))
    done
    
    msg_ok "Container is ready"
}

# Setup container
setup_container() {
    msg_info "Setting up development environment"
    
    # Download and execute setup script
    local setup_url="${BASE_URL}/setup.sh"
    
    pct exec "$CT_ID" -- bash -c "
        export INSTALL_VSCODE='$INSTALL_VSCODE'
        export INSTALL_TEMPLATES='$INSTALL_TEMPLATES'
        export GITHUB_REPO='$GITHUB_REPO'
        export GITHUB_BRANCH='$GITHUB_BRANCH'
        curl -fsSL '$setup_url' | bash
    "
    
    msg_ok "Development environment setup completed"
}

# Get container IP
get_container_ip() {
    local ip
    local timeout=30
    local count=0
    
    while true; do
        ip=$(pct exec "$CT_ID" -- hostname -I 2>/dev/null | awk '{print $1}' | tr -d ' \n')
        
        if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
            echo "$ip"
            return 0
        fi
        
        if [[ $count -ge $timeout ]]; then
            echo "DHCP"
            return 1
        fi
        
        sleep 1
        ((count++))
    done
}

# Show completion info
show_completion() {
    local ip
    ip=$(get_container_ip)
    
    header
    echo -e "${GREEN}🎉 Installation Complete!${NC}"
    echo ""
    echo -e "${CYAN}Container Information:${NC}"
    echo -e "Container ID: ${WHITE}$CT_ID${NC}"
    echo -e "Container Name: ${WHITE}$CT_NAME${NC}"
    echo -e "IP Address: ${WHITE}$ip${NC}"
    echo ""
    
    echo -e "${CYAN}Access Information:${NC}"
    echo -e "SSH: ${GREEN}ssh developer@$ip${NC}"
    echo -e "SSH Key: ${WHITE}/home/developer/.ssh/id_ed25519${NC}"
    
    if [[ "$INSTALL_VSCODE" == "yes" ]]; then
        echo -e "VS Code Server: ${GREEN}http://$ip:8080${NC}"
        echo -e "VS Code Password: ${WHITE}claude-code-dev-2025${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "1. SSH into container: ${PURPLE}ssh developer@$ip${NC}"
    echo -e "2. Authenticate Claude Code: ${PURPLE}claude${NC}"
    echo -e "3. Start new project: ${PURPLE}claude-init my-project${NC}"
    echo -e "4. Check health: ${PURPLE}health-check${NC}"
    echo ""
    
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "• ${PURPLE}claude-init <project>${NC} - Initialize new project"
    echo -e "• ${PURPLE}dev [project]${NC} - Navigate to development directory"
    echo -e "• ${PURPLE}new-project <type> <n>${NC} - Create templated project"
    echo -e "• ${PURPLE}claude --continue${NC} - Continue previous session"
    echo ""
    
    echo -e "${GREEN}✨ Happy coding with Claude Code!${NC}"
}

# Cleanup on error
cleanup() {
    if [[ -n "$CT_ID" ]] && pct status "$CT_ID" &>/dev/null; then
        msg_warn "Cleaning up container $CT_ID due to error"
        pct stop "$CT_ID" 2>/dev/null || true
        pct destroy "$CT_ID" 2>/dev/null || true
    fi
}
trap cleanup ERR

# Main execution
main() {
    # Validation
    check_root
    check_proxmox
    
    # Configuration
    if [[ "${1:-}" == "--auto" ]]; then
        # Auto mode with defaults
        CT_ID=$(get_next_vmid)
        CT_STORAGE=$(get_storage_pools)
        show_config
    else
        # Interactive mode
        configure_basic
        show_config
    fi
    
    # Installation
    create_container
    wait_for_container
    setup_container
    
    # Completion
    show_completion
}

# Help message
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Claude Code Development Environment Installer"
    echo ""
    echo "Usage:"
    echo "  $0              # Interactive installation"
    echo "  $0 --auto       # Automatic installation with defaults"
    echo "  $0 --help       # Show this help"
    echo ""
    echo "Requirements:"
    echo "  - Proxmox VE 8.0+"
    echo "  - Run as root on Proxmox host"
    echo "  - Internet connection"
    echo ""
    exit 0
fi

# Execute main function
main "$@"