#!/usr/bin/env bash

# Proxmox Helper Scripts - [SERVICE_NAME] Installation Template
# Modern, intuitive installation experience
# 
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/[GITHUB_USER]/proxmox-helper-scripts/main/scripts/[SERVICE_DIR]/install.sh)

set -euo pipefail

# Load common UI functions
source <(curl -fsSL https://raw.githubusercontent.com/[GITHUB_USER]/proxmox-helper-scripts/main/templates/common-ui.sh) || {
    echo "Failed to load UI functions"
    exit 1
}

# Configuration
readonly SCRIPT_NAME="[SERVICE_NAME]"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DESCRIPTION="[SERVICE_DESCRIPTION]"
readonly GITHUB_REPO="[GITHUB_USER]/proxmox-helper-scripts"
readonly GITHUB_BRANCH="main"
readonly BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/[SERVICE_DIR]"

# Default container configuration
declare -A CONFIG=(
    ["Container ID"]=""
    ["Container Name"]="[DEFAULT_NAME]"
    ["CPU Cores"]="2"
    ["RAM (MB)"]="2048"
    ["Disk Size (GB)"]="10"
    ["Storage Pool"]="local-lvm"
    ["Network Bridge"]="vmbr0"
    ["OS Template"]="ubuntu-22.04"
)

# Feature flags
declare -A FEATURES=(
    ["Enable SSH"]="yes"
    ["Auto Updates"]="yes"
    ["Monitoring"]="no"
)

# Installation state
INSTALLATION_STAGE=""
CT_ID=""

# Validation functions
check_requirements() {
    INSTALLATION_STAGE="Checking Requirements"
    
    # Check root
    if [[ $EUID -ne 0 ]]; then
        msg_error "This script must be run as root"
    fi
    
    # Check Proxmox
    if ! command -v pveversion >/dev/null 2>&1; then
        msg_error "This script must be run on a Proxmox VE host"
    fi
    
    # Check version
    local pve_version
    pve_version=$(pveversion | grep "pve-manager" | cut -d'/' -f2 | cut -d'-' -f1)
    local major_version
    major_version=$(echo "$pve_version" | cut -d'.' -f1)
    
    if [[ $major_version -lt 8 ]]; then
        msg_warn "Proxmox VE $pve_version detected. Version 8.0+ recommended"
    else
        msg_success "Proxmox VE $pve_version supported"
    fi
}

# Helper functions
get_next_vmid() {
    local next_id=100
    while pct status "$next_id" &>/dev/null || qm status "$next_id" &>/dev/null; do
        ((next_id++))
    done
    echo "$next_id"
}

get_storage_pools() {
    pvesm status -content rootdir | awk 'NR>1 {print $1}' | grep -v '^local$' | head -1
}

get_network_bridges() {
    ip -br link show | grep -E '^vmbr' | awk '{print $1}' | head -1
}

get_available_templates() {
    local storage="${CONFIG["Storage Pool"]}"
    pveam list "$storage" | grep -E "(ubuntu|debian|alpine)" | awk '{print $2}' | sort -u
}

# Interactive configuration with modern UI
configure_basic() {
    section_header "Basic Configuration"
    
    # Container ID
    local default_id
    default_id=$(get_next_vmid)
    while true; do
        prompt_input "Container ID" "$default_id" "CT_ID"
        
        if [[ ! $CT_ID =~ ^[0-9]+$ ]]; then
            msg_warn "Container ID must be a number"
            continue
        fi
        
        if pct status "$CT_ID" &>/dev/null || qm status "$CT_ID" &>/dev/null; do
            msg_warn "ID $CT_ID is already in use"
            continue
        fi
        
        CONFIG["Container ID"]="$CT_ID"
        break
    done
    
    # Container name
    prompt_input "Container name" "${CONFIG["Container Name"]}" "CONFIG[Container Name]"
    
    # Resources
    prompt_input "CPU cores" "${CONFIG["CPU Cores"]}" "CONFIG[CPU Cores]"
    prompt_input "RAM in MB" "${CONFIG["RAM (MB)"]}" "CONFIG[RAM (MB)]"
    prompt_input "Disk size in GB" "${CONFIG["Disk Size (GB)"]}" "CONFIG[Disk Size (GB)]"
    
    # Storage pool
    local available_storage
    available_storage=$(get_storage_pools)
    prompt_input "Storage pool" "${available_storage:-${CONFIG["Storage Pool"]}}" "CONFIG[Storage Pool]"
    
    # Network
    local available_bridge
    available_bridge=$(get_network_bridges)
    prompt_input "Network bridge" "${available_bridge:-${CONFIG["Network Bridge"]}}" "CONFIG[Network Bridge]"
}

configure_features() {
    section_header "Features & Options"
    
    for feature in "${!FEATURES[@]}"; do
        if prompt_yes_no "Enable ${feature}?" "${FEATURES[$feature]}"; then
            FEATURES["$feature"]="yes"
        else
            FEATURES["$feature"]="no"
        fi
    done
}

# Advanced mode with menu selection
configure_advanced() {
    section_header "Advanced Configuration"
    
    local options=(
        "Container Settings"
        "Network Configuration"
        "Security Options"
        "Performance Tuning"
        "Back to Main Menu"
    )
    
    while true; do
        select_option "Select configuration category:" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) configure_container_advanced ;;
            1) configure_network_advanced ;;
            2) configure_security_advanced ;;
            3) configure_performance_advanced ;;
            4) break ;;
        esac
    done
}

# Show configuration summary
show_configuration() {
    display_config CONFIG
    
    if [[ ${#FEATURES[@]} -gt 0 ]]; then
        section_header "Enabled Features"
        for feature in "${!FEATURES[@]}"; do
            if [[ "${FEATURES[$feature]}" == "yes" ]]; then
                echo -e "  ${COLOR_SUCCESS}${SYMBOL_CHECK}${COLOR_RESET} ${feature}"
            fi
        done
        echo ""
    fi
    
    if ! prompt_yes_no "Proceed with installation?" "yes"; then
        msg_warn "Installation cancelled"
        exit 0
    fi
}

# Container creation with progress
create_container() {
    INSTALLATION_STAGE="Creating Container"
    section_header "Creating Container"
    
    # Download template if needed
    start_spinner "Checking OS template..."
    # Template download logic here
    stop_spinner
    msg_success "Template ready"
    
    # Create container
    start_spinner "Creating container ${CONFIG["Container ID"]}..."
    
    local create_cmd="pct create ${CONFIG["Container ID"]} \
        ${TEMPLATE_PATH} \
        --hostname ${CONFIG["Container Name"]} \
        --cores ${CONFIG["CPU Cores"]} \
        --memory ${CONFIG["RAM (MB)"]} \
        --rootfs ${CONFIG["Storage Pool"]}:${CONFIG["Disk Size (GB)"]} \
        --net0 name=eth0,bridge=${CONFIG["Network Bridge"]},ip=dhcp \
        --unprivileged 1 \
        --features nesting=1 \
        --start 0"
    
    if ! eval "$create_cmd" 2>/dev/null; then
        stop_spinner
        msg_error "Failed to create container"
    fi
    
    stop_spinner
    msg_success "Container created successfully"
}

# Setup container with visual feedback
setup_container() {
    INSTALLATION_STAGE="Configuring Container"
    section_header "Container Setup"
    
    # Start container
    status_indicator "running" "Starting container..."
    pct start "${CONFIG["Container ID"]}"
    sleep 5
    status_indicator "success" "Container started"
    
    # Wait for network
    start_spinner "Waiting for network..."
    local count=0
    while ! pct exec "${CONFIG["Container ID"]}" -- ping -c1 google.com &>/dev/null; do
        sleep 2
        ((count++))
        if [[ $count -gt 30 ]]; then
            stop_spinner
            msg_error "Network timeout"
        fi
    done
    stop_spinner
    msg_success "Network ready"
    
    # Run setup script with progress
    echo ""
    echo -e "  ${COLOR_PRIMARY}${BOLD}Installing ${SCRIPT_NAME}...${COLOR_RESET}"
    echo ""
    
    # Visual progress for main installation steps
    local steps=("System Update" "Package Installation" "Service Configuration" "Security Hardening" "Final Setup")
    local total_steps=${#steps[@]}
    
    for i in "${!steps[@]}"; do
        progress_bar $((i)) $total_steps
        status_indicator "running" "${steps[$i]}"
        
        # Execute actual setup commands here
        case $i in
            0) # System Update
                pct exec "${CONFIG["Container ID"]}" -- bash -c "apt-get update && apt-get upgrade -y" &>/dev/null
                ;;
            1) # Package Installation
                # Install required packages
                ;;
            2) # Service Configuration
                # Configure services
                ;;
            3) # Security Hardening
                # Apply security settings
                ;;
            4) # Final Setup
                # Final configuration
                ;;
        esac
        
        status_indicator "success" "${steps[$i]} completed"
        progress_bar $((i + 1)) $total_steps
        echo ""
    done
}

# Display completion information
show_completion() {
    local ip
    ip=$(pct exec "${CONFIG["Container ID"]}" -- hostname -I | awk '{print $1}')
    
    declare -A completion_info=(
        ["Container Information"]="ID: ${CONFIG["Container ID"]}
Name: ${CONFIG["Container Name"]}
IP Address: ${ip:-Pending...}
Resources: ${CONFIG["CPU Cores"]} vCPU, ${CONFIG["RAM (MB)"]}MB RAM, ${CONFIG["Disk Size (GB)"]}GB Disk"
        
        ["Access Details"]="SSH: ssh root@${ip:-container-ip}
Web UI: http://${ip:-container-ip}:8080
API: http://${ip:-container-ip}:3000/api"
        
        ["Quick Commands"]="Enter container: pct enter ${CONFIG["Container ID"]}
View logs: pct exec ${CONFIG["Container ID"]} -- journalctl -f
Stop container: pct stop ${CONFIG["Container ID"]}
Start container: pct start ${CONFIG["Container ID"]}"
    )
    
    display_completion "$SCRIPT_NAME" completion_info
}

# Error handling with cleanup
cleanup_on_error() {
    if [[ -n "${CONFIG["Container ID"]}" ]] && pct status "${CONFIG["Container ID"]}" &>/dev/null; then
        echo ""
        msg_warn "Installation failed at stage: ${INSTALLATION_STAGE}"
        if prompt_yes_no "Remove failed container?" "yes"; then
            pct stop "${CONFIG["Container ID"]}" 2>/dev/null || true
            pct destroy "${CONFIG["Container ID"]}" 2>/dev/null || true
            msg_info "Container removed"
        fi
    fi
}

trap cleanup_on_error ERR

# Main installation flow
main() {
    # Display header
    display_header "$SCRIPT_NAME" "$SCRIPT_VERSION" "$SCRIPT_DESCRIPTION"
    
    # Check requirements
    check_requirements
    
    # Configuration mode
    if [[ "${1:-}" == "--auto" ]]; then
        # Auto mode - use all defaults
        CONFIG["Container ID"]=$(get_next_vmid)
        CONFIG["Storage Pool"]=$(get_storage_pools)
        CONFIG["Network Bridge"]=$(get_network_bridges)
        msg_info "Using automatic configuration"
    else
        # Interactive mode
        configure_basic
        
        if prompt_yes_no "Configure additional features?" "yes"; then
            configure_features
        fi
        
        if prompt_yes_no "Advanced configuration?" "no"; then
            configure_advanced
        fi
    fi
    
    # Show summary and confirm
    show_configuration
    
    # Perform installation
    create_container
    setup_container
    
    # Show completion
    show_completion
}

# Run main function
main "$@"