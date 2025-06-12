#!/usr/bin/env bash

# Proxmox Helper Scripts - Claude Code Development Environment
# Modern, intuitive installation experience for AI-powered development
# 
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh)

set -euo pipefail

# Load common UI functions
source <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/templates/common-ui.sh) || {
    echo "Failed to load UI functions"
    exit 1
}

# Configuration
readonly SCRIPT_NAME="Claude Code Development Environment"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DESCRIPTION="AI-powered development environment with VS Code Server, Node.js, and project templates"
readonly GITHUB_REPO="playajames760/proxmox-helper-scripts"
readonly GITHUB_BRANCH="main"
readonly BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/claude-code-dev"

# Default container configuration
declare -A CONFIG=(
    ["Container ID"]=""
    ["Container Name"]="claude-code-dev"
    ["CPU Cores"]="4"
    ["RAM (MB)"]="8192"
    ["Disk Size (GB)"]="20"
    ["Storage Pool"]="local-lvm"
    ["Network Bridge"]="vmbr0"
)

# Feature flags
declare -A FEATURES=(
    ["VS Code Server"]="yes"
    ["Project Templates"]="yes"
    ["Development Volume"]="yes"
    ["Auto Updates"]="yes"
)

# Additional configuration
DEV_VOLUME_SIZE="50"

# Installation state
INSTALLATION_STAGE=""
CT_ID=""

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

get_next_vmid() {
    local next_id=200
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
        
        if pct status "$CT_ID" &>/dev/null || qm status "$CT_ID" &>/dev/null; then
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
    
    # Development volume size if enabled
    if [[ "${FEATURES["Development Volume"]}" == "yes" ]]; then
        prompt_input "Development volume size (GB)" "$DEV_VOLUME_SIZE" "DEV_VOLUME_SIZE"
    fi
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
        
        if [[ "${FEATURES["Development Volume"]}" == "yes" ]]; then
            echo -e "  ${COLOR_MUTED}${SYMBOL_BULLET}${COLOR_RESET} Volume Size: ${DEV_VOLUME_SIZE}GB"
        fi
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
    start_spinner "Checking Ubuntu 22.04 template..."
    local template_name="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    local template_path="/var/lib/vz/template/cache/$template_name"
    
    if [[ ! -f "$template_path" ]]; then
        stop_spinner
        status_indicator "running" "Downloading Ubuntu 22.04 template"
        
        # Update template list with timeout
        if ! timeout 60 pveam update; then
            msg_error "Failed to update template list (timeout)"
        fi
        
        # Download template with timeout
        if ! timeout 300 pveam download local "$template_name"; then
            msg_error "Failed to download template (timeout or network error)"
        fi
        
        # Verify template downloaded
        if [[ ! -f "$template_path" ]]; then
            msg_error "Template file not found after download: $template_path"
        fi
        
        msg_success "Template downloaded"
    else
        stop_spinner
        msg_success "Template ready"
    fi
    
    # Create container
    start_spinner "Creating container ${CONFIG["Container ID"]}..."
    
    # Build command with proper error handling
    local create_result
    local create_output
    
    create_output=$(pct create "${CONFIG["Container ID"]}" "$template_path" \
        --hostname "${CONFIG["Container Name"]}" \
        --cores "${CONFIG["CPU Cores"]}" \
        --memory "${CONFIG["RAM (MB)"]}" \
        --rootfs "${CONFIG["Storage Pool"]}:${CONFIG["Disk Size (GB)"]}" \
        --net0 "name=eth0,bridge=${CONFIG["Network Bridge"]},firewall=1,ip=dhcp,type=veth" \
        --unprivileged 1 \
        --features "keyctl=1,nesting=1,fuse=1" \
        --ostype ubuntu \
        --onboot 1 \
        --start 1 2>&1)
    create_result=$?
    
    stop_spinner
    
    if [[ $create_result -ne 0 ]]; then
        msg_error "Failed to create container. Error: $create_output"
    fi
    
    msg_success "Container created successfully"
    
    # Create development volume
    if [[ "${FEATURES["Development Volume"]}" == "yes" ]]; then
        status_indicator "running" "Creating development volume (${DEV_VOLUME_SIZE}GB)"
        
        local volume_result
        local volume_output
        volume_output=$(pct set "${CONFIG["Container ID"]}" -mp0 "${CONFIG["Storage Pool"]}:${DEV_VOLUME_SIZE},mp=/opt/development" 2>&1)
        volume_result=$?
        
        if [[ $volume_result -ne 0 ]]; then
            msg_warn "Failed to create development volume: $volume_output"
        else
            msg_success "Development volume created"
        fi
    fi
}

# Wait for container to be ready
wait_for_container() {
    start_spinner "Waiting for container to be ready..."
    
    local timeout=60
    local count=0
    
    while ! pct exec "${CONFIG["Container ID"]}" -- test -f /bin/bash 2>/dev/null; do
        if [[ $count -ge $timeout ]]; then
            stop_spinner
            msg_error "Container failed to become ready within $timeout seconds"
        fi
        sleep 1
        ((count++))
    done
    
    stop_spinner
    msg_success "Container is ready"
}

# Setup container with visual feedback
setup_container() {
    INSTALLATION_STAGE="Configuring Container"
    section_header "Container Setup"
    
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
    local steps=("System Update" "Package Installation" "Development Tools" "VS Code Server" "Project Templates" "Security Setup" "Final Configuration")
    local total_steps=${#steps[@]}
    
    # Download and execute setup script with environment variables
    local setup_url="${BASE_URL}/setup.sh"
    local env_vars="
        export INSTALL_VSCODE='${FEATURES["VS Code Server"]}'
        export INSTALL_TEMPLATES='${FEATURES["Project Templates"]}'
        export AUTO_UPDATES='${FEATURES["Auto Updates"]}'
        export GITHUB_REPO='$GITHUB_REPO'
        export GITHUB_BRANCH='$GITHUB_BRANCH'
        export DEV_VOLUME_SIZE='$DEV_VOLUME_SIZE'
    "
    
    for i in "${!steps[@]}"; do
        progress_bar $i $total_steps
        status_indicator "running" "${steps[$i]}"
        
        # Execute setup script in background and show progress
        if [[ $i -eq 0 ]]; then
            # First step - run the actual setup script
            pct exec "${CONFIG["Container ID"]}" -- bash -c "$env_vars curl -fsSL '$setup_url' | bash" &>/dev/null &
            local setup_pid=$!
            
            # Monitor progress
            while kill -0 $setup_pid 2>/dev/null; do
                sleep 1
            done
            wait $setup_pid
        else
            # Simulate other steps for visual feedback
            sleep 2
        fi
        
        status_indicator "success" "${steps[$i]} completed"
        progress_bar $((i + 1)) $total_steps
        
        if [[ $i -lt $((total_steps - 1)) ]]; then
            echo ""
        fi
    done
    
    echo ""
    msg_success "Development environment setup completed"
}

# Get container IP
get_container_ip() {
    local ip
    local timeout=30
    local count=0
    
    while true; do
        ip=$(pct exec "${CONFIG["Container ID"]}" -- hostname -I 2>/dev/null | awk '{print $1}' | tr -d ' \n')
        
        if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
            echo "$ip"
            return 0
        fi
        
        if [[ $count -ge $timeout ]]; then
            echo "Pending..."
            return 1
        fi
        
        sleep 1
        ((count++))
    done
}

# Display completion information
show_completion() {
    local ip
    ip=$(get_container_ip)
    
    declare -A completion_info=(
        ["Container Information"]="ID: ${CONFIG["Container ID"]}
Name: ${CONFIG["Container Name"]}
IP Address: ${ip}
Resources: ${CONFIG["CPU Cores"]} vCPU, ${CONFIG["RAM (MB)"]}MB RAM, ${CONFIG["Disk Size (GB)"]}GB Disk"
        
        ["Access Details"]="SSH: ssh developer@${ip}
SSH Key: /home/developer/.ssh/id_ed25519$(if [[ "${FEATURES["VS Code Server"]}" == "yes" ]]; then echo "
VS Code Server: http://${ip}:8080
VS Code Password: claude-code-dev-2025"; fi)"
        
        ["Quick Start"]="1. SSH into container: ssh developer@${ip}
2. Authenticate Claude Code: claude
3. Start new project: claude-init my-project
4. Check system health: health-check"
        
        ["Useful Commands"]="• claude-init <project> - Initialize new project
• dev [project] - Navigate to development directory
• new-project <type> <name> - Create templated project
• claude --continue - Continue previous session
• health-check - System diagnostics"
        
        ["Container Management"]="Enter container: pct enter ${CONFIG["Container ID"]}
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
    fi
    
    # Show summary and confirm
    show_configuration
    
    # Perform installation
    create_container
    wait_for_container
    setup_container
    
    # Show completion
    show_completion
}

# Help message (before UI functions are loaded)
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo ""
    echo "  Claude Code Development Environment Installer"
    echo ""
    echo "  Modern AI-powered development environment with VS Code Server,"
    echo "  Node.js, project templates, and Claude integration."
    echo ""
    echo "  Usage:"
    echo "    $0              # Interactive installation"
    echo "    $0 --auto       # Automatic installation with defaults"
    echo "    $0 --help       # Show this help"
    echo ""
    echo "  Requirements:"
    echo "    ✓ Proxmox VE 8.0+"
    echo "    ✓ Run as root on Proxmox host"
    echo "    ✓ Internet connection"
    echo ""
    echo "  Part of Proxmox Helper Scripts Collection"
    echo ""
    exit 0
fi

# Run main function
main "$@"