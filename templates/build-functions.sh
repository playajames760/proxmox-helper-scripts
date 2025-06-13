#!/usr/bin/env bash

# Proxmox Helper Scripts - Build Functions Library
# Modern, robust functions for container and VM creation
# Based on community-scripts best practices with enhanced error handling

set -euo pipefail

# ===============================
# Color and Symbol Definitions
# ===============================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

readonly CHECKMARK="✓"
readonly CROSSMARK="✗"
readonly INFO="ⓘ"
readonly WARNING="⚠"
readonly ARROW="→"
readonly SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# ===============================
# Core Messaging Functions
# ===============================

msg_info() {
    echo -e "${BLUE}${INFO}${NC} ${BOLD}INFO:${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}${CHECKMARK}${NC} ${BOLD}SUCCESS:${NC} $1"
}

msg_error() {
    echo -e "${RED}${CROSSMARK}${NC} ${BOLD}ERROR:${NC} $1" >&2
    exit 1
}

msg_warn() {
    echo -e "${YELLOW}${WARNING}${NC} ${BOLD}WARNING:${NC} $1"
}

msg_step() {
    echo -e "${CYAN}${ARROW}${NC} ${BOLD}STEP:${NC} $1"
}

# Enhanced spinner with process tracking
show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spinstr=$SPINNER
    local temp
    
    echo -ne "${BLUE}${message}${NC} "
    
    while ps -p "$pid" > /dev/null 2>&1; do
        temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    
    wait "$pid"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        printf "    \b\b\b\b${GREEN}${CHECKMARK}${NC}\n"
    else
        printf "    \b\b\b\b${RED}${CROSSMARK}${NC}\n"
        return $exit_code
    fi
}

# ===============================
# Validation Functions
# ===============================

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
    
    if [[ $major_version -lt 7 ]]; then
        msg_error "Proxmox VE 7.0+ required. Found: $pve_version"
    elif [[ $major_version -lt 8 ]]; then
        msg_warn "Proxmox VE $pve_version detected. Version 8.0+ recommended for best compatibility"
    else
        msg_ok "Proxmox VE $pve_version supported"
    fi
}

check_storage_space() {
    local storage_pool="$1"
    local required_gb="$2"
    
    # Check if storage pool exists
    if ! pvesm status 2>/dev/null | grep -q "^${storage_pool}"; then
        local available_pools
        available_pools=$(pvesm status 2>/dev/null | awk 'NR>1 {print $1}' | tr '\n' ' ')
        msg_error "Storage pool '$storage_pool' not found. Available pools: $available_pools"
    fi
    
    # Check if storage supports rootdir content using storage.cfg
    local supports_rootdir=false
    if grep -q "^[[:alpha:]]*:.*${storage_pool}" /etc/pve/storage.cfg 2>/dev/null; then
        local content_line
        content_line=$(awk "/^[[:alpha:]]*:.*${storage_pool}$/{flag=1;next} flag && /content/{print;flag=0}" /etc/pve/storage.cfg 2>/dev/null)
        if [[ "$content_line" =~ rootdir ]]; then
            supports_rootdir=true
        fi
    fi
    
    if [[ "$supports_rootdir" != "true" ]]; then
        local content_display="${content_line:-"not specified"}"
        msg_error "Storage pool '$storage_pool' does not support containers (rootdir content). Content: $content_display"
    fi
    
    # Get available space - handle different storage types
    local available_gb total_gb
    local storage_info
    storage_info=$(pvesm status 2>/dev/null | awk -v pool="$storage_pool" '$1 == pool {print $4, $5}')
    
    if [[ -n "$storage_info" ]]; then
        # Parse total and used space
        local total_bytes used_bytes
        total_bytes=$(echo "$storage_info" | awk '{print $1}')
        used_bytes=$(echo "$storage_info" | awk '{print $2}')
        
        if [[ -n "$total_bytes" && -n "$used_bytes" ]]; then
            # pvesm status values are in KB, convert to GB
            total_gb=$((total_bytes / 1024 / 1024))
            available_gb=$(((total_bytes - used_bytes) / 1024 / 1024))
        else
            msg_warn "Could not parse storage space for '$storage_pool', assuming sufficient space"
            return 0
        fi
    else
        msg_warn "Could not get storage info for '$storage_pool', assuming sufficient space"
        return 0
    fi
    
    if [[ $available_gb -lt $required_gb ]]; then
        msg_error "Insufficient storage in '$storage_pool': need ${required_gb}GB, have ${available_gb}GB available (${total_gb}GB total)"
    fi
    
    msg_ok "Storage validated: ${available_gb}GB available in '$storage_pool' (${total_gb}GB total)"
}

check_memory_available() {
    local required_mb="$1"
    
    local total_mb
    total_mb=$(free -m | awk 'NR==2{print $2}')
    local used_mb
    used_mb=$(free -m | awk 'NR==2{print $3}')
    local available_mb=$((total_mb - used_mb))
    
    if [[ $available_mb -lt $required_mb ]]; then
        msg_warn "Host memory may be insufficient: need ${required_mb}MB, have ${available_mb}MB available"
    else
        msg_ok "Memory validated: ${available_mb}MB available"
    fi
}

validate_container_id() {
    local ct_id="$1"
    
    if [[ ! $ct_id =~ ^[0-9]+$ ]]; then
        msg_error "Container ID must be a number"
    fi
    
    if [[ $ct_id -lt 100 || $ct_id -gt 999999999 ]]; then
        msg_error "Container ID must be between 100 and 999999999"
    fi
    
    if pct status "$ct_id" &>/dev/null || qm status "$ct_id" &>/dev/null; then
        msg_error "ID $ct_id is already in use"
    fi
}

validate_network_bridge() {
    local bridge="$1"
    
    if ! ip link show "$bridge" &>/dev/null; then
        msg_error "Network bridge '$bridge' does not exist"
    fi
    
    msg_ok "Network bridge '$bridge' validated"
}

# ===============================
# Container Template Functions
# ===============================

get_latest_template() {
    local os="$1"
    local storage="$2"
    
    msg_info "Updating template list..."
    
    # Update template list with timeout
    if ! timeout 60 pveam update 2>/dev/null; then
        msg_warn "Failed to update template list, using cached list"
    fi
    
    local template
    case "$os" in
        "ubuntu-22.04")
            template=$(pveam available "$storage" | grep -E "ubuntu-22\.04.*standard" | sort -V | tail -1 | awk '{print $2}')
            ;;
        "ubuntu-20.04")
            template=$(pveam available "$storage" | grep -E "ubuntu-20\.04.*standard" | sort -V | tail -1 | awk '{print $2}')
            ;;
        "debian-12")
            template=$(pveam available "$storage" | grep -E "debian-12.*standard" | sort -V | tail -1 | awk '{print $2}')
            ;;
        *)
            msg_error "Unsupported OS template: $os"
            ;;
    esac
    
    if [[ -z "$template" ]]; then
        msg_error "No $os template found. Check internet connection and storage configuration."
    fi
    
    echo "$template"
}

download_template() {
    local storage="$1"
    local template="$2"
    
    local template_path="${storage}:vztmpl/${template}"
    local local_path="/var/lib/vz/template/cache/${template}"
    
    # Check if template already exists
    if [[ -f "$local_path" ]]; then
        msg_ok "Template already available: $template"
        echo "$template_path"
        return 0
    fi
    
    msg_info "Downloading template: $template"
    
    # Download with progress and timeout
    {
        timeout 900 pveam download "$storage" "$template" 2>&1 | while read -r line; do
            if [[ $line =~ ([0-9]+)% ]]; then
                echo "Download progress: ${BASH_REMATCH[1]}%"
            fi
        done
    } &
    
    local download_pid=$!
    
    if ! show_spinner $download_pid "Downloading $template"; then
        msg_error "Failed to download template: $template"
    fi
    
    # Verify download
    if [[ ! -f "$local_path" ]]; then
        msg_error "Template file not found after download: $local_path"
    fi
    
    msg_ok "Template downloaded: $template"
    echo "$template_path"
}

# ===============================
# Container Creation Functions
# ===============================

create_container() {
    local ct_id="$1"
    local hostname="$2"
    local template_path="$3"
    local cores="$4"
    local memory="$5"
    local storage_config="$6"
    local network_config="$7"
    local features="$8"
    
    msg_step "Creating container $ct_id ($hostname)"
    
    # Build creation command
    local create_cmd=(
        "pct" "create" "$ct_id" "$template_path"
        "--hostname" "$hostname"
        "--cores" "$cores"
        "--memory" "$memory"
        "--rootfs" "$storage_config"
        "--net0" "$network_config"
        "--features" "$features"
        "--unprivileged" "1"
        "--ostype" "ubuntu"
        "--onboot" "1"
        "--start" "0"
    )
    
    # Execute creation with timeout and error handling
    {
        timeout 300 "${create_cmd[@]}" 2>&1
    } &
    
    local create_pid=$!
    
    if ! show_spinner $create_pid "Creating container"; then
        msg_error "Failed to create container $ct_id"
    fi
    
    msg_ok "Container $ct_id created successfully"
}

start_container() {
    local ct_id="$1"
    
    msg_step "Starting container $ct_id"
    
    {
        timeout 120 pct start "$ct_id" 2>&1
    } &
    
    local start_pid=$!
    
    if ! show_spinner $start_pid "Starting container"; then
        msg_error "Failed to start container $ct_id"
    fi
    
    msg_ok "Container $ct_id started successfully"
}

wait_for_container_boot() {
    local ct_id="$1"
    local max_wait="${2:-60}"
    
    msg_step "Waiting for container $ct_id to boot"
    
    local count=0
    while ! pct exec "$ct_id" -- test -f /bin/bash 2>/dev/null; do
        if [[ $count -ge $max_wait ]]; then
            msg_error "Container $ct_id failed to boot within $max_wait seconds"
        fi
        sleep 1
        ((count++))
    done
    
    msg_ok "Container $ct_id is ready"
}

wait_for_network() {
    local ct_id="$1"
    local max_wait="${2:-120}"
    
    msg_step "Waiting for network connectivity in container $ct_id"
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "archive.ubuntu.com")
    local count=0
    
    while true; do
        local network_ready=true
        
        for host in "${test_hosts[@]}"; do
            if ! pct exec "$ct_id" -- ping -c1 -W5 "$host" &>/dev/null; then
                network_ready=false
                break
            fi
        done
        
        if [[ "$network_ready" == "true" ]]; then
            break
        fi
        
        if [[ $count -ge $max_wait ]]; then
            msg_error "Network not available in container $ct_id after $max_wait seconds"
        fi
        
        sleep 2
        ((count++))
    done
    
    msg_ok "Network connectivity verified"
}

# ===============================
# Container Configuration Functions
# ===============================

run_in_container() {
    local ct_id="$1"
    local command="$2"
    local description="${3:-Running command}"
    
    msg_step "$description"
    
    {
        pct exec "$ct_id" -- bash -c "$command" 2>&1
    } &
    
    local exec_pid=$!
    
    if ! show_spinner $exec_pid "$description"; then
        msg_error "Command failed in container $ct_id: $command"
    fi
    
    msg_ok "$description completed"
}

install_packages() {
    local ct_id="$1"
    shift
    local packages=("$@")
    
    # Update package lists first
    run_in_container "$ct_id" "apt-get update" "Updating package lists"
    
    # Install packages with retry logic
    for package in "${packages[@]}"; do
        local max_retries=3
        local retry=0
        
        while [[ $retry -lt $max_retries ]]; do
            if pct exec "$ct_id" -- apt-get install -y "$package" 2>/dev/null; then
                msg_ok "Installed: $package"
                break
            else
                ((retry++))
                if [[ $retry -eq $max_retries ]]; then
                    msg_error "Failed to install $package after $max_retries attempts"
                else
                    msg_warn "Retrying installation of $package (attempt $retry/$max_retries)"
                    sleep 5
                fi
            fi
        done
    done
}

# ===============================
# Utility Functions
# ===============================

get_next_vmid() {
    local start_id="${1:-100}"
    local next_id=$start_id
    
    while pct status "$next_id" &>/dev/null || qm status "$next_id" &>/dev/null; do
        ((next_id++))
    done
    
    echo "$next_id"
}

get_storage_pools() {
    # Get all storage pools that support rootdir content (containers)
    local pools=()
    
    # Parse pvesm status output correctly - skip first 2 lines (headers)
    while IFS= read -r line; do
        # Extract pool name and status from each line
        local pool_name status
        pool_name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        
        # Skip empty lines and ensure we have a valid pool name
        if [[ -n "$pool_name" && "$pool_name" != "Name" && "$status" == "active" ]]; then
            # Check if this pool supports containers by looking at storage.cfg
            local supports_rootdir=false
            if grep -q "^[[:alpha:]]*:.*${pool_name}" /etc/pve/storage.cfg 2>/dev/null; then
                # Use a more robust approach to find content line
                local content_line
                content_line=$(awk "/^[[:alpha:]]*:.*${pool_name}$/{flag=1;next} flag && /content/{print;flag=0}" /etc/pve/storage.cfg 2>/dev/null)
                if [[ "$content_line" =~ rootdir ]]; then
                    supports_rootdir=true
                fi
            fi
            
            # Add to pools if it supports containers
            if [[ "$supports_rootdir" == "true" ]]; then
                pools+=("$pool_name")
            fi
        fi
    done < <(pvesm status 2>/dev/null | tail -n +2)
    
    # If no pools found via config parsing, use a more direct approach
    if [[ ${#pools[@]} -eq 0 ]]; then
        # Check known storage pools that commonly support containers
        for pool in local-lvm utility jellyfin-data frigate; do
            # Check if pool exists and is active
            if pvesm status 2>/dev/null | grep -q "^${pool}.*active"; then
                # Check storage.cfg for rootdir content using awk instead of grep -A5
                if grep -q "^[[:alpha:]]*:.*${pool}" /etc/pve/storage.cfg 2>/dev/null; then
                    local content_line
                    content_line=$(awk "/^[[:alpha:]]*:.*${pool}$/{flag=1;next} flag && /content/{print;flag=0}" /etc/pve/storage.cfg 2>/dev/null)
                    if [[ "$content_line" =~ rootdir ]]; then
                        pools+=("$pool")
                    fi
                fi
            fi
        done
    fi
    
    # Ensure we return at least one working pool
    if [[ ${#pools[@]} -eq 0 ]]; then
        echo "local-lvm"
    else
        printf '%s\n' "${pools[@]}" | head -10
    fi
}

get_network_bridges() {
    ip -br link show | grep -E '^vmbr[0-9]+' | awk '{print $1}' | head -5
}

get_container_ip() {
    local ct_id="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        local ip
        ip=$(pct exec "$ct_id" -- hostname -I 2>/dev/null | awk '{print $1}' | tr -d ' \n')
        
        if [[ -n "$ip" && "$ip" != "127.0.0.1" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "Pending..."
    return 1
}

# ===============================
# Error Handling and Cleanup
# ===============================

cleanup_failed_container() {
    local ct_id="$1"
    
    if [[ -z "$ct_id" ]]; then
        return 0
    fi
    
    if pct status "$ct_id" &>/dev/null; then
        msg_warn "Cleaning up failed container $ct_id"
        
        # Stop container if running
        if pct status "$ct_id" | grep -q "status: running"; then
            msg_info "Stopping container $ct_id"
            pct stop "$ct_id" 2>/dev/null || true
            sleep 5
        fi
        
        # Destroy container
        msg_info "Removing container $ct_id"
        pct destroy "$ct_id" 2>/dev/null || true
        
        msg_ok "Container $ct_id removed"
    fi
}

# ===============================
# Header and Information Display
# ===============================

header_info() {
    clear
    cat << "EOF"
    ____                                    __  __      __                 
   / __ \_________  _  ______ ___  ____  __/ / / /__  / /___  ___  _____   
  / /_/ / ___/ __ \| |/_/ __ `__ \/ __ \/ /  /_/ _ \/ / __ \/ _ \/ ___/   
 / ____/ /  / /_/ />  </ / / / / / /_/ / /  __/  __/ / /_/ /  __/ /       
/_/   /_/   \____/_/|_/_/ /_/ /_/\____/_/   \___/___/_/ .___/\___/_/        
                                                     /_/                    
   __  __     __                 _____           _       __      
  / / / /__  / /___  ___  _____  / ___/__________(_)___  / /______
 / /_/ / _ \/ / __ \/ _ \/ ___/  \__ \/ ___/ ___/ / __ \/ __/ ___/
/ __  /  __/ / /_/ /  __/ /     ___/ / /__/ /  / / /_/ / /_(__  ) 
/_/ /_/\___/_/ .___/\___/_/     /____/\___/_/  /_/ .___/\__/____/  
            /_/                                /_/                
EOF
}

variables() {
    # Function to display and set variables - override in individual scripts
    :
}

build_container() {
    # Main container build function - override in individual scripts
    :
}

description() {
    # Function to display service description - override in individual scripts
    :
}

# ===============================
# Export Functions
# ===============================

# Export all functions for use in other scripts
export -f msg_info msg_ok msg_error msg_warn msg_step show_spinner
export -f check_root check_proxmox check_storage_space check_memory_available
export -f validate_container_id validate_network_bridge
export -f get_latest_template download_template
export -f create_container start_container wait_for_container_boot wait_for_network
export -f run_in_container install_packages
export -f get_next_vmid get_storage_pools get_network_bridges get_container_ip
export -f cleanup_failed_container header_info variables build_container description