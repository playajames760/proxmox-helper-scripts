#!/usr/bin/env bash

# Proxmox Helper Scripts - Claude Code Development Environment
# Modern, reliable installation for AI-powered development
# Based on community-scripts architecture with enhanced features
# 
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh)

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="Claude Code Development Environment"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DESCRIPTION="Complete AI-powered development environment with Claude Code, VS Code Server, and modern dev tools"
readonly GITHUB_REPO="playajames760/proxmox-helper-scripts"
readonly GITHUB_BRANCH="main"
readonly BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Load build functions
source <(curl -fsSL "${BASE_URL}/templates/build-functions.sh") || {
    echo "❌ Failed to load build functions"
    exit 1
}

# ===============================
# Container Configuration
# ===============================

# Default container configuration
CT_TYPE="1"          # 1=Unprivileged container, 0=Privileged
CT_NAME="claude-code-dev"
CT_ID=""
CT_CORES="4"
CT_RAM="8192"
CT_STORAGE="20"
CT_STORAGE_POOL=""
CT_NET_BRIDGE=""
CT_OS_TEMPLATE="ubuntu-22.04"

# Feature flags
INSTALL_VSCODE="1"
INSTALL_DOCKER="1"
INSTALL_NODE="1"
INSTALL_TEMPLATES="1"
AUTO_START="1"
DEV_VOLUME_SIZE="50"

# Installation tracking
INSTALLATION_STAGE=""
CLEANUP_ENABLED="1"

# ===============================
# Application Metadata
# ===============================

app="Claude Code Dev Environment"
var_tags="development;ai;claude;nodejs;vscode;docker"
var_cpu="4"
var_ram="8192"  
var_disk="20"
var_os="ubuntu"
var_version="22.04"
var_unprivileged="1"

# ===============================
# Error Handling Setup
# ===============================

cleanup_on_error() {
    local exit_code=$?
    
    if [[ "$CLEANUP_ENABLED" == "1" && -n "${CT_ID:-}" ]]; then
        echo ""
        msg_error "Installation failed at stage: ${INSTALLATION_STAGE:-Unknown} (exit code: $exit_code)"
        
        # Provide stage-specific troubleshooting
        case "${INSTALLATION_STAGE:-}" in
            "Validation")
                echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
                echo -e "  1. Check Proxmox version: pveversion"
                echo -e "  2. Verify storage pools: pvesm status"
                echo -e "  3. Check network bridges: ip link show"
                ;;
            "Template Download")
                echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
                echo -e "  1. Check internet connectivity: ping 8.8.8.8"
                echo -e "  2. Verify storage access: pvesm status ${CT_STORAGE_POOL:-local}"
                echo -e "  3. Try manual download: pveam download ${CT_STORAGE_POOL:-local} <template>"
                ;;
            "Container Creation")
                echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
                echo -e "  1. Check container status: pct status ${CT_ID}"
                echo -e "  2. Review Proxmox logs: journalctl -u pvedaemon"
                echo -e "  3. Verify template: ls -la /var/lib/vz/template/cache/"
                ;;
            "Container Setup")
                echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
                echo -e "  1. Check container logs: pct exec ${CT_ID} -- journalctl -n 50"
                echo -e "  2. Test network: pct exec ${CT_ID} -- ping google.com"
                echo -e "  3. Manual setup: pct enter ${CT_ID}"
                ;;
        esac
        
        echo ""
        if [[ -t 0 ]]; then  # Check if running interactively
            read -p "Remove failed container ${CT_ID}? [y/N]: " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cleanup_failed_container "$CT_ID"
            fi
        else
            msg_warn "Run 'pct destroy ${CT_ID}' to remove failed container"
        fi
    fi
    
    exit $exit_code
}

cleanup_on_exit() {
    # Clean exit handler
    :
}

trap cleanup_on_error ERR
trap cleanup_on_exit EXIT INT TERM

# ===============================
# Variable Configuration
# ===============================

variables() {
    # Set CT_ID if not provided
    if [[ -z "${CT_ID}" ]]; then
        CT_ID=$(get_next_vmid 200)
    fi
    
    # Set storage pool if not provided
    if [[ -z "${CT_STORAGE_POOL}" ]]; then
        local available_pools
        available_pools=($(get_storage_pools))
        CT_STORAGE_POOL="${available_pools[0]:-local-lvm}"
    fi
    
    # Set network bridge if not provided
    if [[ -z "${CT_NET_BRIDGE}" ]]; then
        local available_bridges
        available_bridges=($(get_network_bridges))
        CT_NET_BRIDGE="${available_bridges[0]:-vmbr0}"
    fi
    
    # Override with environment variables if set
    CT_TYPE="${CT_TYPE:-$var_unprivileged}"
    CT_CORES="${CORES:-$CT_CORES}"
    CT_RAM="${RAM:-$CT_RAM}"
    CT_STORAGE="${STORAGE:-$CT_STORAGE}"
}

# ===============================
# Interactive Configuration
# ===============================

interactive_config() {
    echo ""
    msg_info "=== Interactive Configuration ==="
    echo ""
    
    # Container ID
    while true; do
        read -p "Container ID [$CT_ID]: " input_id
        input_id="${input_id:-$CT_ID}"
        
        if validate_container_id "$input_id" 2>/dev/null; then
            CT_ID="$input_id"
            break
        else
            msg_warn "Invalid or already used ID: $input_id"
        fi
    done
    
    # Container name
    read -p "Container name [$CT_NAME]: " input_name
    CT_NAME="${input_name:-$CT_NAME}"
    
    # Resources
    read -p "CPU cores [$CT_CORES]: " input_cores
    CT_CORES="${input_cores:-$CT_CORES}"
    
    read -p "RAM in MB [$CT_RAM]: " input_ram
    CT_RAM="${input_ram:-$CT_RAM}"
    
    read -p "Disk size in GB [$CT_STORAGE]: " input_storage
    CT_STORAGE="${input_storage:-$CT_STORAGE}"
    
    # Storage pool selection
    echo ""
    msg_info "Available storage pools:"
    local pools
    pools=($(get_storage_pools))
    for i in "${!pools[@]}"; do
        echo "  $((i+1)). ${pools[i]}"
    done
    read -p "Select storage pool [1]: " pool_choice
    pool_choice="${pool_choice:-1}"
    CT_STORAGE_POOL="${pools[$((pool_choice-1))]:-${pools[0]}}"
    
    # Network bridge selection
    echo ""
    msg_info "Available network bridges:"
    local bridges
    bridges=($(get_network_bridges))
    for i in "${!bridges[@]}"; do
        echo "  $((i+1)). ${bridges[i]}"
    done
    read -p "Select network bridge [1]: " bridge_choice
    bridge_choice="${bridge_choice:-1}"
    CT_NET_BRIDGE="${bridges[$((bridge_choice-1))]:-${bridges[0]}}"
    
    # Features
    echo ""
    msg_info "Optional features:"
    
    read -p "Install VS Code Server? [Y/n]: " vscode_choice
    INSTALL_VSCODE=$([[ "${vscode_choice,,}" =~ ^n ]] && echo "0" || echo "1")
    
    read -p "Install Docker? [Y/n]: " docker_choice
    INSTALL_DOCKER=$([[ "${docker_choice,,}" =~ ^n ]] && echo "0" || echo "1")
    
    read -p "Install project templates? [Y/n]: " templates_choice
    INSTALL_TEMPLATES=$([[ "${templates_choice,,}" =~ ^n ]] && echo "0" || echo "1")
    
    if [[ "$INSTALL_TEMPLATES" == "1" ]]; then
        read -p "Development volume size in GB [$DEV_VOLUME_SIZE]: " vol_size
        DEV_VOLUME_SIZE="${vol_size:-$DEV_VOLUME_SIZE}"
    fi
}

# ===============================
# Validation and Preparation
# ===============================

validate_environment() {
    INSTALLATION_STAGE="Validation"
    
    msg_step "Validating environment"
    
    # Basic checks
    check_root
    check_proxmox
    
    # Resource validation
    validate_container_id "$CT_ID"
    check_storage_space "$CT_STORAGE_POOL" "$((CT_STORAGE + DEV_VOLUME_SIZE))"
    check_memory_available "$CT_RAM"
    validate_network_bridge "$CT_NET_BRIDGE"
    
    msg_ok "Environment validation passed"
}

# ===============================
# Container Creation
# ===============================

create_claude_container() {
    INSTALLATION_STAGE="Template Download"
    
    # Get and download template
    local template_name
    template_name=$(get_latest_template "$CT_OS_TEMPLATE" "$CT_STORAGE_POOL")
    
    local template_path
    template_path=$(download_template "$CT_STORAGE_POOL" "$template_name")
    
    INSTALLATION_STAGE="Container Creation"
    
    # Build container configuration
    local storage_config="${CT_STORAGE_POOL}:${CT_STORAGE}"
    local network_config="name=eth0,bridge=${CT_NET_BRIDGE},firewall=1,ip=dhcp,type=veth"
    local features="keyctl=1,nesting=1,fuse=1"
    
    # Create container
    create_container \
        "$CT_ID" \
        "$CT_NAME" \
        "$template_path" \
        "$CT_CORES" \
        "$CT_RAM" \
        "$storage_config" \
        "$network_config" \
        "$features"
    
    # Start and prepare container
    start_container "$CT_ID"
    wait_for_container_boot "$CT_ID"
    wait_for_network "$CT_ID"
    
    # Add development volume if requested
    if [[ "$INSTALL_TEMPLATES" == "1" && "$DEV_VOLUME_SIZE" -gt 0 ]]; then
        msg_step "Adding development volume (${DEV_VOLUME_SIZE}GB)"
        if pct set "$CT_ID" -mp0 "${CT_STORAGE_POOL}:${DEV_VOLUME_SIZE},mp=/opt/development" 2>/dev/null; then
            msg_ok "Development volume added"
        else
            msg_warn "Failed to add development volume"
        fi
    fi
}

# ===============================
# Container Setup
# ===============================

setup_claude_environment() {
    INSTALLATION_STAGE="Container Setup"
    
    msg_step "Setting up Claude Code development environment"
    
    # Update system
    run_in_container "$CT_ID" "
        apt-get update && 
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    " "Updating system packages"
    
    # Install essential packages
    local essential_packages=(
        "curl" "wget" "git" "build-essential" "software-properties-common"
        "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
        "unzip" "zip" "jq" "tree" "htop" "nano" "vim" "tmux" "sudo"
        "openssh-server" "python3" "python3-pip" "zsh" "fail2ban" "ufw"
    )
    
    install_packages "$CT_ID" "${essential_packages[@]}"
    
    # Install Node.js 20 LTS
    if [[ "$INSTALL_NODE" == "1" ]]; then
        run_in_container "$CT_ID" "
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &&
            apt-get install -y nodejs
        " "Installing Node.js 20 LTS"
    fi
    
    # Install Docker
    if [[ "$INSTALL_DOCKER" == "1" ]]; then
        run_in_container "$CT_ID" "
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg &&
            echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null &&
            apt-get update &&
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin &&
            systemctl enable docker &&
            systemctl start docker
        " "Installing Docker"
    fi
    
    # Install GitHub CLI
    run_in_container "$CT_ID" "
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&
        apt-get update &&
        apt-get install -y gh
    " "Installing GitHub CLI"
    
    # Install Claude Code
    run_in_container "$CT_ID" "
        npm install -g @anthropic-ai/claude-code@latest
    " "Installing Claude Code"
    
    # Install additional npm packages
    if [[ "$INSTALL_NODE" == "1" ]]; then
        run_in_container "$CT_ID" "
            npm install -g yarn pnpm typescript eslint prettier nodemon pm2 http-server
        " "Installing development npm packages"
    fi
    
    # Download and execute setup script
    msg_step "Configuring development environment"
    
    local setup_env="
        export INSTALL_VSCODE='$INSTALL_VSCODE'
        export INSTALL_DOCKER='$INSTALL_DOCKER'
        export INSTALL_TEMPLATES='$INSTALL_TEMPLATES'
        export GITHUB_REPO='$GITHUB_REPO'
        export GITHUB_BRANCH='$GITHUB_BRANCH'
        export DEV_VOLUME_SIZE='$DEV_VOLUME_SIZE'
        export AUTO_START='$AUTO_START'
    "
    
    run_in_container "$CT_ID" "
        $setup_env
        curl -fsSL '${BASE_URL}/scripts/claude-code-dev/setup.sh' | bash
    " "Executing setup script"
    
    msg_ok "Claude Code environment setup completed"
}

# ===============================
# Post-Installation Validation
# ===============================

validate_installation() {
    msg_step "Validating installation"
    
    local validation_failed=false
    
    # Check services
    local required_services=("ssh")
    [[ "$INSTALL_DOCKER" == "1" ]] && required_services+=("docker")
    [[ "$INSTALL_VSCODE" == "1" ]] && required_services+=("code-server")
    
    for service in "${required_services[@]}"; do
        if ! pct exec "$CT_ID" -- systemctl is-active --quiet "$service" 2>/dev/null; then
            msg_warn "Service $service is not running"
            validation_failed=true
        fi
    done
    
    # Check tools
    local required_tools=("git" "curl")
    [[ "$INSTALL_NODE" == "1" ]] && required_tools+=("node" "npm")
    [[ "$INSTALL_DOCKER" == "1" ]] && required_tools+=("docker")
    
    # Check Claude Code specifically
    if pct exec "$CT_ID" -- command -v claude &>/dev/null; then
        local claude_version
        claude_version=$(pct exec "$CT_ID" -- claude --version 2>/dev/null || echo "unknown")
        msg_ok "Claude Code installed: $claude_version"
    else
        msg_warn "Claude Code command not found"
        validation_failed=true
    fi
    
    for tool in "${required_tools[@]}"; do
        if ! pct exec "$CT_ID" -- command -v "$tool" &>/dev/null; then
            msg_warn "Tool $tool is not available"
            validation_failed=true
        fi
    done
    
    # Check network connectivity to Claude API
    if pct exec "$CT_ID" -- curl -s --connect-timeout 5 https://api.anthropic.com/v1/models &>/dev/null; then
        msg_ok "Claude API connectivity verified"
    else
        msg_warn "Cannot reach Claude API (may affect authentication)"
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        msg_warn "Some components failed validation"
        return 1
    else
        msg_ok "All components validated successfully"
        return 0
    fi
}

# ===============================
# Completion Display
# ===============================

show_completion() {
    local container_ip
    container_ip=$(get_container_ip "$CT_ID")
    
    clear
    echo ""
    echo "🎉 Claude Code Development Environment Ready!"
    echo "=========================================="
    echo ""
    echo "📋 Container Information:"
    echo "   ID: $CT_ID"
    echo "   Name: $CT_NAME"
    echo "   IP Address: $container_ip"
    echo "   Resources: $CT_CORES vCPU, ${CT_RAM}MB RAM, ${CT_STORAGE}GB Disk"
    echo ""
    echo "🚀 Access Methods:"
    echo "   Container Access: pct enter $CT_ID && su - developer"
    echo "   SSH Access: ssh developer@$container_ip"
    
    if [[ "$INSTALL_VSCODE" == "1" ]]; then
        echo "   VS Code Server: http://$container_ip:8080"
        local vscode_pass
        if vscode_pass=$(pct exec "$CT_ID" -- cat /home/developer/.vscode-password 2>/dev/null); then
            echo "   VS Code Password: $vscode_pass"
        fi
    fi
    
    echo ""
    echo "🔑 Authentication Setup:"
    echo "   1. Enter container: pct enter $CT_ID && su - developer"
    echo "   2. Run: claude"
    echo "   3. Follow authentication prompts"
    echo "   4. Choose 'Console' for headless or 'App' for browser auth"
    echo ""
    echo "⚡ Quick Start Commands:"
    echo "   claude                    # Start Claude Code"
    echo "   claude-init my-project    # Initialize new project"
    echo "   dev [project-name]        # Navigate to project"
    echo "   health-check              # System diagnostics"
    echo ""
    
    if [[ "$INSTALL_TEMPLATES" == "1" ]]; then
        echo "📁 Development Structure:"
        echo "   /opt/development/projects/  # Your projects"
        echo "   /opt/development/templates/ # Project templates"
        echo "   /opt/development/bin/       # Custom scripts"
        echo ""
    fi
    
    echo "📚 Documentation:"
    echo "   Authentication Guide: /home/developer/AUTHENTICATION.md"
    echo "   Project Documentation: /home/developer/README.md"
    echo ""
    
    if ! validate_installation &>/dev/null; then
        echo "⚠️  Some components need attention. Run 'health-check' in the container for details."
        echo ""
    fi
    
    echo "✅ Installation completed successfully!"
    echo ""
}

# ===============================
# Main Execution Flow
# ===============================

main() {
    # Disable cleanup during normal header display
    CLEANUP_ENABLED="0"
    
    # Display header
    header_info
    
    echo ""
    echo -e "${BOLD}${CYAN}$SCRIPT_NAME${NC}"
    echo -e "${BLUE}Version: $SCRIPT_VERSION${NC}"
    echo -e "${GREEN}$SCRIPT_DESCRIPTION${NC}"
    echo ""
    
    # Re-enable cleanup after header
    CLEANUP_ENABLED="1"
    
    # Process command line arguments
    case "${1:-}" in
        "--auto")
            msg_info "Using automatic configuration with defaults"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [--auto|--help]"
            echo ""
            echo "Options:"
            echo "  --auto    Use automatic configuration with defaults"
            echo "  --help    Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CORES=4           Number of CPU cores"
            echo "  RAM=8192          RAM in MB"
            echo "  STORAGE=20        Disk size in GB"
            echo "  CT_ID=200         Container ID"
            echo "  CT_NAME=name      Container name"
            echo ""
            exit 0
            ;;
        "")
            # Interactive mode
            interactive_config
            ;;
        *)
            msg_error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
    
    # Set variables
    variables
    
    # Show configuration summary
    echo ""
    msg_info "=== Configuration Summary ==="
    echo "  Container ID: $CT_ID"
    echo "  Container Name: $CT_NAME"
    echo "  CPU Cores: $CT_CORES"
    echo "  RAM: ${CT_RAM}MB"
    echo "  Storage: ${CT_STORAGE}GB"
    echo "  Storage Pool: $CT_STORAGE_POOL"
    echo "  Network Bridge: $CT_NET_BRIDGE"
    echo "  VS Code Server: $([[ $INSTALL_VSCODE == "1" ]] && echo "Yes" || echo "No")"
    echo "  Docker: $([[ $INSTALL_DOCKER == "1" ]] && echo "Yes" || echo "No")"
    echo "  Project Templates: $([[ $INSTALL_TEMPLATES == "1" ]] && echo "Yes" || echo "No")"
    echo ""
    
    if [[ -t 0 && "${1:-}" != "--auto" ]]; then
        read -p "Proceed with installation? [Y/n]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            msg_info "Installation cancelled"
            exit 0
        fi
    fi
    
    # Execute installation
    validate_environment
    create_claude_container
    setup_claude_environment
    
    # Show completion
    show_completion
}

# ===============================
# Script Execution
# ===============================

# Run main function with all arguments
main "$@"