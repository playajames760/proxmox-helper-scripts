#!/usr/bin/env bash

# UI Demo Script - Showcases the modern UI components
# Run this to see all UI elements in action

set -euo pipefail

# Source the common UI functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-ui.sh"

# Demo function
demo_ui() {
    # 1. Display header
    display_header "UI Components Demo" "1.0.0" "Interactive showcase of modern UI elements"
    
    read -p "Press Enter to continue..." _
    
    # 2. Messages demo
    section_header "Message Types"
    
    msg_info "This is an informational message"
    msg_success "This is a success message"
    msg_warn "This is a warning message"
    status_indicator "running" "This shows a running process"
    status_indicator "error" "This shows an error state"
    
    echo ""
    read -p "Press Enter to continue..." _
    
    # 3. Input prompts demo
    section_header "Input Prompts"
    
    local name service_type
    prompt_input "Enter your name" "John Doe" "name"
    echo -e "  ${COLOR_MUTED}You entered: ${COLOR_HIGHLIGHT}$name${COLOR_RESET}\n"
    
    if prompt_yes_no "Do you want to see more demos?" "yes"; then
        msg_success "Great! Let's continue"
    fi
    
    echo ""
    read -p "Press Enter to continue..." _
    
    # 4. Selection menu demo
    section_header "Selection Menu"
    
    echo -e "${COLOR_MUTED}Use arrow keys to navigate, Enter to select:${COLOR_RESET}\n"
    
    local options=("Web Server" "Database" "Development Environment" "Monitoring Stack")
    select_option "Choose a service type:" "${options[@]}"
    local selected=$?
    
    echo -e "\n  ${COLOR_MUTED}You selected: ${COLOR_HIGHLIGHT}${options[$selected]}${COLOR_RESET}\n"
    read -p "Press Enter to continue..." _
    
    # 5. Progress indicators demo
    section_header "Progress Indicators"
    
    echo -e "${COLOR_PRIMARY}Progress Bar Demo:${COLOR_RESET}\n"
    for i in {0..10}; do
        progress_bar $i 10
        sleep 0.2
    done
    
    echo -e "\n${COLOR_PRIMARY}Spinner Demo:${COLOR_RESET}\n"
    start_spinner "Processing data..."
    sleep 3
    stop_spinner
    msg_success "Processing complete"
    
    echo ""
    read -p "Press Enter to continue..." _
    
    # 6. Configuration table demo
    section_header "Configuration Display"
    
    declare -A sample_config=(
        ["Container ID"]="101"
        ["Container Name"]="demo-service"
        ["CPU Cores"]="4"
        ["Memory"]="8192 MB"
        ["Disk Size"]="20 GB"
        ["Network"]="Bridge (vmbr0)"
        ["Storage"]="local-lvm"
    )
    
    display_config sample_config "Service Configuration"
    
    read -p "Press Enter to continue..." _
    
    # 7. Status updates demo
    section_header "Installation Simulation"
    
    local steps=("Downloading packages" "Installing dependencies" "Configuring service" "Starting service" "Verifying installation")
    local total=${#steps[@]}
    
    for i in "${!steps[@]}"; do
        progress_bar $i $total
        status_indicator "running" "${steps[$i]}..."
        sleep 1
        status_indicator "success" "${steps[$i]} complete"
        progress_bar $((i + 1)) $total
        echo ""
    done
    
    echo ""
    read -p "Press Enter to continue..." _
    
    # 8. Completion banner demo
    declare -A completion_info=(
        ["Service Information"]="Name: Demo Service
Status: Active
Version: 1.0.0
Port: 8080"
        
        ["Access Details"]="Web UI: http://localhost:8080
API: http://localhost:8080/api
Docs: http://localhost:8080/docs"
        
        ["Quick Commands"]="Start: systemctl start demo
Stop: systemctl stop demo
Logs: journalctl -u demo -f
Status: systemctl status demo"
    )
    
    display_completion "Demo Service" completion_info
}

# Run the demo
demo_ui