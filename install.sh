#!/usr/bin/env bash

# install.sh - Proxmox Helper Scripts Main Installer
# Interactive installer that helps you choose and install various applications

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source shared utilities
source "$SCRIPT_DIR/installers/shared/common.sh"

# Script version
SCRIPT_VERSION="1.0.0"

# Available installers
declare -A INSTALLERS=(
    ["claude-code"]="Claude Code Development Environment|Complete development environment with Claude Code, Node.js, and essential MCP servers"
)

# Function to display main banner
show_main_banner() {
    show_banner "🚀 Proxmox Helper Scripts" "Choose Your Installation" "$SCRIPT_VERSION"
}

# Function to display available installers
show_installer_menu() {
    echo -e "${CYAN}${BOLD}Available Installers:${NC}"
    echo
    
    local i=1
    for installer in "${!INSTALLERS[@]}"; do
        local info="${INSTALLERS[$installer]}"
        local title="${info%%|*}"
        local description="${info##*|}"
        
        echo -e "${WHITE}${BOLD}[$i]${NC} ${GREEN}$title${NC}"
        echo -e "    ${DIM}$description${NC}"
        echo
        ((i++))
    done
    
    echo -e "${WHITE}${BOLD}[q]${NC} ${RED}Quit${NC}"
    echo
}

# Function to get user selection
get_user_selection() {
    local choice
    local installer_array=()
    
    # Build array of installer keys
    for installer in "${!INSTALLERS[@]}"; do
        installer_array+=("$installer")
    done
    
    while true; do
        echo -ne "${CYAN}${BOLD}Select an installer [1-${#installer_array[@]}, q]: ${NC}"
        read -r choice
        
        case "$choice" in
            [qQ]|quit|exit)
                msg_info "Goodbye!"
                exit 0
                ;;
            ''|*[!0-9]*)
                msg_error "Please enter a valid number or 'q' to quit"
                continue
                ;;
            *)
                if [[ "$choice" -ge 1 && "$choice" -le "${#installer_array[@]}" ]]; then
                    local selected_installer="${installer_array[$((choice-1))]}"
                    echo "$selected_installer"
                    return 0
                else
                    msg_error "Please enter a number between 1 and ${#installer_array[@]}"
                    continue
                fi
                ;;
        esac
    done
}

# Function to run selected installer
run_installer() {
    local installer="$1"
    local installer_path="$SCRIPT_DIR/installers/$installer/install.sh"
    
    if [[ ! -f "$installer_path" ]]; then
        msg_error "Installer not found: $installer_path"
        exit 1
    fi
    
    if [[ ! -x "$installer_path" ]]; then
        msg_warning "Making installer executable..."
        chmod +x "$installer_path"
    fi
    
    msg_info "Launching ${INSTALLERS[$installer]%%|*}..."
    echo
    
    # Execute the installer
    exec "$installer_path"
}

# Function to check prerequisites
check_prerequisites() {
    msg_step "Checking prerequisites..."
    
    # Check if running as root for container operations
    if [[ $EUID -ne 0 ]]; then
        msg_warning "Not running as root. Container creation will not be available."
        echo -e "${DIM}Run with sudo for full functionality.${NC}"
        echo
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        msg_error "No internet connection available"
        exit 1
    fi
    
    msg_success "Prerequisites check completed"
    echo
}

# Function to show environment info
show_environment_info() {
    msg_step "Environment Detection"
    
    local environments=()
    environments+=("💻 Local system")
    
    if is_proxmox; then
        environments+=("🏠 Proxmox VE (LXC containers)")
    fi
    
    if has_docker; then
        environments+=("🐳 Docker (containers)")
    fi
    
    echo -e "${GREEN}Available environments:${NC}"
    for env in "${environments[@]}"; do
        echo -e "  ${CHECK_MARK} $env"
    done
    echo
}

# Main function
main() {
    # Show banner
    show_main_banner
    
    # Log file info
    echo -e "${DIM}📝 Installation log: $LOG_FILE${NC}"
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Show environment info
    show_environment_info
    
    # Show installer menu
    show_installer_menu
    
    # Get user selection
    local selected_installer
    selected_installer=$(get_user_selection)
    
    # Run selected installer
    run_installer "$selected_installer"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi